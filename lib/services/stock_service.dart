import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class StockService {
  final _supabase = Supabase.instance.client;
  final String _table = 'inventory';

  // --- SABİT LİSTELER ---
  static const List<String> categories = ['Sürücü', 'PLC', 'HMI', 'Şalt', 'Sensör', 'Diğer'];
  
  static const List<String> driveBrands = ['Danfoss', 'GMT', 'INVT', 'ABB', 'Schneider', 'Diğer'];
  static const List<String> plcModels = ['GMT', 'Siemens', 'Delta', 'Fatek', 'Diğer'];
  
  static const List<String> hmiBrands = ['ABB', 'Weintek', 'GMT', 'Diğer'];
  static const List<double> hmiSizes = [4.3, 7.0, 10.0, 12.0, 15.0]; // inç cinsinden

  static const List<double> kwValues = [0.75, 1.1, 1.5, 2.2, 3.0, 3.7, 4.0, 5.5, 7.5, 11.0, 15.0, 18.5, 22.0, 30.0, 37.0, 45.0];

  // --- YARDIMCI METODLAR ---
  // Sayı formatını standartlaştırır: 5.0 -> 5, 5.5 -> 5.5
  static String formatKw(double kw) {
    if (kw % 1 == 0) {
      return kw.toInt().toString();
    }
    return kw.toString();
  }
  
  // HMI boyut formatı (7.0 -> 7, 4.3 -> 4.3)
  static String formatInch(double val) {
    if (val % 1 == 0) {
      return val.toInt().toString();
    }
    return val.toString();
  }

  Future<List<Map<String, dynamic>>> getStocks() async {
    final response = await _supabase.from(_table).select().order('name', ascending: true);
    return List<Map<String, dynamic>>.from(response);
  }

  Future<void> addStock(Map<String, dynamic> data) async {
    await _supabase.from(_table).insert(data);
  }

  Future<void> updateStock(int id, Map<String, dynamic> data) async {
    await _supabase.from(_table).update(data).eq('id', id);
  }

  Future<void> deleteStock(int id) async {
    await _supabase.from(_table).delete().eq('id', id);
  }

  Future<void> updateQuantity(int id, int newQuantity) async {
    await _supabase.from(_table).update({'quantity': newQuantity}).eq('id', id);
  }

  // --- GÜNCELLENMİŞ STOK DÜŞME MANTIĞI ---
  
  Future<String?> decreaseStockByName(String productName, {int amount = 1}) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('name', productName)
          .maybeSingle();

      if (response == null) {
        debugPrint('Stokta hiç yok (Tanımsız): $productName');
        return productName; 
      }

      final currentQty = response['quantity'] as int? ?? 0;
      final newQty = currentQty - amount;
      
      await _supabase
          .from(_table)
          .update({'quantity': newQty})
          .eq('id', response['id']);
          
      debugPrint('Stoktan düşüldü: $productName (Eski: $currentQty -> Yeni: $newQty)');

      if (newQty < 0) {
        return productName;
      }
      
      return null;
    } catch (e) {
      debugPrint('Stok düşme hatası ($productName): $e');
      return productName;
    }
  }

  Future<void> increaseStockByName(String productName, {int amount = 1}) async {
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('name', productName)
          .maybeSingle();

      if (response == null) return;

      final currentQty = response['quantity'] as int? ?? 0;
      final newQty = currentQty + amount;
      
      await _supabase
          .from(_table)
          .update({'quantity': newQty})
          .eq('id', response['id']);
          
      debugPrint('Stok iade edildi: $productName (Yeni Stok: $newQty)');
    } catch (e) {
      debugPrint('Stok iade hatası ($productName): $e');
    }
  }

  // İş Emrinden Gelen Verilerle Stok Düş ve Eksikleri Raporla
  Future<List<String>> processTicketStockUsage({
    String? plcModel,
    String? aspiratorBrand,
    double? aspiratorKw,
    String? vantBrand,
    double? vantKw,
    String? hmiBrand,
    double? hmiSize,
  }) async {
    List<String> missingItems = [];

    // PLC Kontrol
    if (plcModel != null && plcModel.isNotEmpty && plcModel != 'Diğer') {
      final name = '$plcModel PLC';
      final result = await decreaseStockByName(name);
      if (result != null) missingItems.add(result);
    }

    // Aspiratör Sürücü Kontrol
    if (aspiratorBrand != null && aspiratorKw != null && aspiratorBrand != 'Diğer') {
      final kwStr = formatKw(aspiratorKw);
      final name = '$aspiratorBrand $kwStr kW Sürücü';
      final result = await decreaseStockByName(name);
      if (result != null) missingItems.add(result);
    }

    // Vantilatör Sürücü Kontrol
    if (vantBrand != null && vantKw != null && vantBrand != 'Diğer') {
      final kwStr = formatKw(vantKw);
      final name = '$vantBrand $kwStr kW Sürücü';
      final result = await decreaseStockByName(name);
      if (result != null) missingItems.add(result);
    }

    // HMI Kontrol
    if (hmiBrand != null && hmiSize != null && hmiBrand != 'Diğer') {
      final inchStr = formatInch(hmiSize);
      // İsimlendirme formatı: Marka Boyut inç HMI (Örn: Weintek 7 inç HMI)
      final name = '$hmiBrand $inchStr inç HMI';
      final result = await decreaseStockByName(name);
      if (result != null) missingItems.add(result);
    }

    return missingItems;
  }

  // Jet Fan Listelerini İşler
  Future<List<String>> processJetFanStockUsage({
    required List<Map<String, dynamic>> smokeFans,
    required List<Map<String, dynamic>> freshFans,
  }) async {
     List<String> missingItems = [];

     // Duman Fanlarını Düş
     for (var fan in smokeFans) {
       final brand = fan['brand'] as String?;
       final kw = fan['kw'] as double?;

       if (brand != null && kw != null && brand != 'Diğer') {
          final kwStr = formatKw(kw);
          final name = '$brand $kwStr kW Sürücü'; // Fan motoru sürücü olarak mı geçiyor yoksa motor mu?
          // Varsayım: Stok listesinde bu fanlar için 'Sürücü' veya direkt 'Motor' tanımı olabilir.
          // Mevcut kod yapısında 'Sürücü' olarak kaydediyoruz gibi görünüyor. 
          // Eğer bunlar 'Motor' ise isim convention değişmeli.
          // Kullanıcı "motor marka ve kw" dedi.
          // Ancak stock_service.dart'taki format: '$aspiratorBrand $kwStr kW Sürücü'
          // Biz de aynı formatı kullanalım şimdilik:
          
          final result = await decreaseStockByName(name);
          if (result != null) missingItems.add(result);
       }
     }

     // Taze Hava Fanlarını Düş
     for (var fan in freshFans) {
       final brand = fan['brand'] as String?;
       final kw = fan['kw'] as double?;

       if (brand != null && kw != null && brand != 'Diğer') {
          final kwStr = formatKw(kw);
          final name = '$brand $kwStr kW Sürücü';
          final result = await decreaseStockByName(name);
          if (result != null) missingItems.add(result);
       }
     }

     return missingItems;
  }

  // İş Emri Güncellenmeden Önce Eski Stokları İade Et
  Future<void> revertTicketStockUsage({
    String? plcModel,
    String? aspiratorBrand,
    double? aspiratorKw,
    String? vantBrand,
    double? vantKw,
    String? hmiBrand,
    double? hmiSize,
  }) async {
    if (plcModel != null && plcModel.isNotEmpty && plcModel != 'Diğer') {
      await increaseStockByName('$plcModel PLC');
    }

    if (aspiratorBrand != null && aspiratorKw != null && aspiratorBrand != 'Diğer') {
      final kwStr = formatKw(aspiratorKw);
      await increaseStockByName('$aspiratorBrand $kwStr kW Sürücü');
    }

    if (vantBrand != null && vantKw != null && vantBrand != 'Diğer') {
      final kwStr = formatKw(vantKw);
      await increaseStockByName('$vantBrand $kwStr kW Sürücü');
    }

    if (hmiBrand != null && hmiSize != null && hmiBrand != 'Diğer') {
      final inchStr = formatInch(hmiSize);
      await increaseStockByName('$hmiBrand $inchStr inç HMI');
    }
  }
}
