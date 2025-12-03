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
  
  /// Stok miktarını azaltır (ürün adına göre)
  /// 
  /// ⚠️ RACE CONDITION UYARISI: Bu metod "read-modify-write" pattern kullanıyor.
  /// Eğer iki kullanıcı aynı anda aynı ürünü düşürürse, stok tutarsızlığı olabilir.
  /// 
  /// Örnek Senaryo:
  /// - Stok: 10
  /// - Kullanıcı A okur: 10
  /// - Kullanıcı B okur: 10
  /// - Kullanıcı A yazar: 9
  /// - Kullanıcı B yazar: 9 (Halbuki 8 olmalıydı!)
  /// 
  /// 💡 İYİLEŞTİRME ÖNERİSİ: Supabase'de PostgreSQL RPC fonksiyonu oluşturup
  /// atomik UPDATE ... SET quantity = quantity - $1 WHERE ... şeklinde kullanılmalı.
  /// Bu sayede veritabanı seviyesinde race condition önlenir.
  /// 
  /// Şimdilik bu kod çalışır ancak yüksek eşzamanlılık durumlarında dikkatli olunmalı.
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
    String? aspiratorModel, // Yeni: Model parametresi
    double? aspiratorKw,
    String? vantBrand,
    String? vantModel, // Yeni: Model parametresi
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

    // Aspiratör Sürücü Kontrol (Model varsa: "Marka Model kW Sürücü", yoksa: "Marka kW Sürücü")
    if (aspiratorBrand != null && aspiratorKw != null && aspiratorBrand != 'Diğer') {
      final kwStr = formatKw(aspiratorKw);
      String name;
      if (aspiratorModel != null && aspiratorModel.isNotEmpty) {
        name = '$aspiratorBrand $aspiratorModel $kwStr kW Sürücü';
      } else {
        name = '$aspiratorBrand $kwStr kW Sürücü';
      }
      final result = await decreaseStockByName(name);
      if (result != null) missingItems.add(result);
    }

    // Vantilatör Sürücü Kontrol (Model varsa: "Marka Model kW Sürücü", yoksa: "Marka kW Sürücü")
    if (vantBrand != null && vantKw != null && vantBrand != 'Diğer') {
      final kwStr = formatKw(vantKw);
      String name;
      if (vantModel != null && vantModel.isNotEmpty) {
        name = '$vantBrand $vantModel $kwStr kW Sürücü';
      } else {
        name = '$vantBrand $kwStr kW Sürücü';
      }
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
    String? aspiratorModel, // Yeni: Model parametresi
    double? aspiratorKw,
    String? vantBrand,
    String? vantModel, // Yeni: Model parametresi
    double? vantKw,
    String? hmiBrand,
    double? hmiSize,
  }) async {
    if (plcModel != null && plcModel.isNotEmpty && plcModel != 'Diğer') {
      await increaseStockByName('$plcModel PLC');
    }

    if (aspiratorBrand != null && aspiratorKw != null && aspiratorBrand != 'Diğer') {
      final kwStr = formatKw(aspiratorKw);
      String name;
      if (aspiratorModel != null && aspiratorModel.isNotEmpty) {
        name = '$aspiratorBrand $aspiratorModel $kwStr kW Sürücü';
      } else {
        name = '$aspiratorBrand $kwStr kW Sürücü';
      }
      await increaseStockByName(name);
    }

    if (vantBrand != null && vantKw != null && vantBrand != 'Diğer') {
      final kwStr = formatKw(vantKw);
      String name;
      if (vantModel != null && vantModel.isNotEmpty) {
        name = '$vantBrand $vantModel $kwStr kW Sürücü';
      } else {
        name = '$vantBrand $kwStr kW Sürücü';
      }
      await increaseStockByName(name);
    }

    if (hmiBrand != null && hmiSize != null && hmiBrand != 'Diğer') {
      final inchStr = formatInch(hmiSize);
      await increaseStockByName('$hmiBrand $inchStr inç HMI');
    }
  }

  // --- MARKA MODELLERİ YÖNETİMİ ---
  
  /// Varsayılan markaları veritabanına yükler (eğer yoksa)
  Future<void> initializeDefaultBrands() async {
    await _ensureCategoryDefaults('Sürücü', driveBrands);
    await _ensureCategoryDefaults('PLC', plcModels);
    await _ensureCategoryDefaults('HMI', hmiBrands);
  }

  Future<void> _ensureCategoryDefaults(String category, List<String> defaults) async {
    try {
      final response = await _supabase
          .from('brand_models')
          .select('id')
          .eq('category', category)
          .limit(1);
      
      if ((response as List).isEmpty) {
        debugPrint('$category için varsayılan markalar yükleniyor...');
        for (var brand in defaults) {
          if (brand == 'Diğer') continue;
          try {
            await addBrand(brand, category);
          } catch (_) {} // Zaten varsa geç
        }
      }
    } catch (e) {
      debugPrint('$category varsayılanları yükleme hatası: $e');
    }
  }
  
  /// Belirli bir markanın alt modellerini getirir (kategoriye göre)
  Future<List<String>> getBrandModels(String brandName, String category) async {
    try {
      final response = await _supabase
          .from('brand_models')
          .select('model_name')
          .eq('brand_name', brandName)
          .eq('category', category)
          .order('model_name', ascending: true);
      
      return (response as List)
          .map((e) => e['model_name'] as String)
          .toList();
    } catch (e) {
      debugPrint('Marka modelleri çekme hatası ($brandName, $category): $e');
      return [];
    }
  }
  
  /// Kategoriye göre markaları getirir (sadece marka kayıtları, model_name = '' olanlar)
  Future<List<String>> getBrandsByCategory(String category) async {
    try {
      final response = await _supabase
          .from('brand_models')
          .select('brand_name')
          .eq('category', category)
          .eq('model_name', '') // Sadece marka kayıtlarını getir (model_name boş olanlar)
          .order('brand_name', ascending: true);
      
      final brands = (response as List)
          .map((e) => e['brand_name'] as String)
          .toList();
      
      return brands;
    } catch (e) {
      debugPrint('Kategori markaları çekme hatası ($category): $e');
      return [];
    }
  }
  
  /// Yeni marka ekler
  Future<void> addBrand(String brandName, String category) async {
    try {
      // Marka zaten varsa ekleme
      final existing = await _supabase
          .from('brand_models')
          .select('id')
          .eq('brand_name', brandName)
          .eq('category', category)
          .limit(1);
      
      if ((existing as List).isEmpty) {
        // İlk model olarak boş bir kayıt ekle (sadece marka için)
        await _supabase.from('brand_models').insert({
          'brand_name': brandName.trim(),
          'category': category,
          'model_name': '', // Boş model adı (sadece marka kaydı için)
        });
      }
    } catch (e) {
      debugPrint('Marka ekleme hatası: $e');
      rethrow;
    }
  }
  
  /// Markayı siler (tüm modelleriyle birlikte)
  Future<void> deleteBrand(String brandName, String category) async {
    try {
      await _supabase
          .from('brand_models')
          .delete()
          .eq('brand_name', brandName)
          .eq('category', category);
    } catch (e) {
      debugPrint('Marka silme hatası: $e');
      rethrow;
    }
  }

  /// Tüm marka-modelleri getirir (Ayar sayfası için)
  Future<List<Map<String, dynamic>>> getAllBrandModels() async {
    try {
      final response = await _supabase
          .from('brand_models')
          .select()
          .neq('model_name', '') // Boş model adlarını filtrele (sadece marka kayıtları)
          .order('category', ascending: true)
          .order('brand_name', ascending: true)
          .order('model_name', ascending: true);
      
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Tüm marka modelleri çekme hatası: $e');
      return [];
    }
  }
  
  /// Tüm markaları getirir (kategoriye göre gruplanmış)
  Future<Map<String, List<String>>> getAllBrands() async {
    try {
      final response = await _supabase
          .from('brand_models')
          .select('brand_name, category')
          .eq('model_name', '') // Sadece marka kayıtları
          .order('category', ascending: true)
          .order('brand_name', ascending: true);
      
      final Map<String, List<String>> result = {};
      for (var item in response as List) {
        final category = item['category'] as String;
        final brand = item['brand_name'] as String;
        if (!result.containsKey(category)) {
          result[category] = [];
        }
        if (!result[category]!.contains(brand)) {
          result[category]!.add(brand);
        }
      }
      
      return result;
    } catch (e) {
      debugPrint('Tüm markaları çekme hatası: $e');
      return {};
    }
  }

  /// Yeni marka modeli ekler
  Future<void> addBrandModel(String brandName, String modelName, String category) async {
    try {
      final trimmedModelName = modelName.trim();
      
      // Boş model adı kontrolü
      if (trimmedModelName.isEmpty) {
        throw Exception('Model adı boş olamaz');
      }
      
      // Aynı marka+model kombinasyonu zaten varsa ekleme
      final existing = await _supabase
          .from('brand_models')
          .select('id')
          .eq('brand_name', brandName)
          .eq('model_name', trimmedModelName)
          .eq('category', category)
          .limit(1);
      
      if ((existing as List).isNotEmpty) {
        throw Exception('Bu model zaten mevcut');
      }
      
      await _supabase.from('brand_models').insert({
        'brand_name': brandName,
        'model_name': trimmedModelName,
        'category': category,
      });
    } catch (e) {
      debugPrint('Marka modeli ekleme hatası: $e');
      rethrow;
    }
  }

  /// Marka modeli siler
  Future<void> deleteBrandModel(int id) async {
    try {
      await _supabase.from('brand_models').delete().eq('id', id);
    } catch (e) {
      debugPrint('Marka modeli silme hatası: $e');
      rethrow;
    }
  }
}
