import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/ticket_part.dart';

class StockService {
  final _supabase = Supabase.instance.client;
  final String _table = 'products';

  /// Supabase `products` kaydını UI stok formatına dönüştürür.
  Map<String, dynamic> _productToStock(Map<String, dynamic> product) {
    final specifications = Map<String, dynamic>.from(
      product['specifications'] as Map? ?? const <String, dynamic>{},
    );
    return {
      ...product,
      'quantity': product['stock_quantity'] ?? 0,
      'critical_level': product['minimum_stock'] ?? 0,
      'stock_tracking_started':
          product['stock_tracking_started'] == true ||
          ((product['stock_quantity'] as num?) ?? 0) > 0,
      'barcode': specifications['barcode'] ?? product['code'] ?? '',
      'shelf_location': specifications['shelf_location'] ?? '',
    };
  }

  /// UI stok verilerini `products` veritabanı sütunlarına dönüştürür.
  Map<String, dynamic> _stockDataToProduct(
    Map<String, dynamic> data, {
    Map<String, dynamic>? current,
  }) {
    final specifications = Map<String, dynamic>.from(
      current?['specifications'] as Map? ?? const <String, dynamic>{},
    );

    if (data.containsKey('barcode')) {
      final barcode = data['barcode']?.toString().trim() ?? '';
      if (barcode.isEmpty) {
        specifications.remove('barcode');
      } else {
        specifications['barcode'] = barcode;
      }
    }

    if (data.containsKey('shelf_location')) {
      final shelf = data['shelf_location']?.toString().trim() ?? '';
      if (shelf.isEmpty) {
        specifications.remove('shelf_location');
      } else {
        specifications['shelf_location'] = shelf;
      }
    }

    return {
      if (data.containsKey('name')) 'name': data['name'],
      if (data.containsKey('category')) 'category': data['category'],
      if (data.containsKey('unit')) 'unit': data['unit'],
      if (data.containsKey('brand')) 'brand': data['brand'],
      if (data.containsKey('model')) 'model': data['model'],
      if (data.containsKey('quantity')) 'stock_quantity': data['quantity'],
      if (data.containsKey('quantity') && ((data['quantity'] as num?) ?? 0) > 0)
        'stock_tracking_started': true,
      if (data.containsKey('critical_level'))
        'minimum_stock': data['critical_level'],
      'specifications': specifications,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
  }

  // --- SABİT LİSTELER ---
  static const List<String> categories = [
    'Sürücü',
    'PLC',
    'HMI',
    'Şalt',
    'Sensör',
    'Diğer',
  ];

  static const List<String> plcModels = [
    'GMT',
    'Siemens',
    'Delta',
    'Fatek',
    'Diğer',
  ];

  static const List<String> hmiBrands = ['ABB', 'Weintek', 'GMT', 'Diğer'];
  static const List<double> hmiSizes = [4.3, 7.0, 10.0, 12.0, 15.0];

  static const List<double> kwValues = [
    0.75,
    1.1,
    1.5,
    2.2,
    3.0,
    3.7,
    4.0,
    5.5,
    7.5,
    11.0,
    15.0,
    18.5,
    22.0,
    30.0,
    37.0,
    45.0,
  ];

  // --- YARDIMCI METODLAR ---
  static String formatKw(double kw) {
    if (kw % 1 == 0) return kw.toInt().toString();
    return kw.toString();
  }

  static String formatInch(double val) {
    if (val % 1 == 0) return val.toInt().toString();
    return val.toString();
  }

  /// Tüm stok ürünlerini sayfalayarak çeker.
  Future<List<Map<String, dynamic>>> getStocks() async {
    const pageSize = 500;
    final stocks = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      final response = await _supabase
          .from(_table)
          .select()
          .order('name', ascending: true)
          .range(offset, offset + pageSize - 1);
      final page = List<Map<String, dynamic>>.from(response);
      stocks.addAll(page.map(_productToStock));
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return stocks;
  }

  /// Barkod veya ürün koduna göre tek ürün getirir.
  Future<Map<String, dynamic>?> getStockByBarcode(String barcode) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return null;
    final stocks = await getStocks();
    for (final stock in stocks) {
      final storedBarcode = stock['barcode']?.toString().trim() ?? '';
      final code = stock['code']?.toString().trim() ?? '';
      if (storedBarcode == normalized || code == normalized) return stock;
    }
    return null;
  }

  /// Eksik malzemesi olan iş emri kayıtlarını getirir.
  Future<List<Map<String, dynamic>>> getTicketsWithMissingParts() async {
    final response = await _supabase
        .from('tickets')
        .select('''
          id,
          title,
          job_code,
          missing_parts,
          device_brand,
          device_model,
          planned_date,
          created_at,
          customers (
            id,
            name
          )
        ''')
        .not('missing_parts', 'is', null)
        .neq('missing_parts', '')
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(response);
  }

  /// Yeni ürün stok kaydı oluşturur.
  Future<void> addStock(Map<String, dynamic> data) async {
    final now = DateTime.now().toUtc();
    final token = now.microsecondsSinceEpoch.toString();
    await _supabase.from(_table).insert({
      'id': 'stock-$token',
      'code': 'STK-$token',
      'brand': data['brand'] ?? '',
      'model': data['model'] ?? '',
      ..._stockDataToProduct(data),
    });
  }

  /// Stok kaydını günceller.
  Future<void> updateStock(String id, Map<String, dynamic> data) async {
    final current =
        await _supabase
            .from(_table)
            .select('specifications')
            .eq('id', id)
            .single();
    await _supabase
        .from(_table)
        .update(_stockDataToProduct(data, current: current))
        .eq('id', id);
  }

  /// Barkodu doğrudan ürüne bağlar.
  Future<void> linkBarcodeToStock(String id, String barcode) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) {
      throw Exception('Barkod boş olamaz.');
    }

    final current =
        await _supabase
            .from(_table)
            .select('specifications')
            .eq('id', id)
            .single();
    final specifications = Map<String, dynamic>.from(
      current['specifications'] as Map? ?? const <String, dynamic>{},
    );
    specifications['barcode'] = normalized;
    await _supabase
        .from(_table)
        .update({'specifications': specifications})
        .eq('id', id);
  }

  /// Stok kaydını siler.
  Future<void> deleteStock(String id) async {
    await _supabase.from(_table).delete().eq('id', id);
  }

  /// Stok miktarını günceller.
  Future<void> updateQuantity(String id, int newQuantity) async {
    await _supabase
        .from(_table)
        .update({
          'stock_quantity': newQuantity,
          'stock_tracking_started': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);
  }

  // --- STOCK MOVEMENTS (STOK HAREKETLERİ) ---

  /// Stok hareket geçmişini getirir.
  Future<List<Map<String, dynamic>>> getStockMovements({
    int limit = 100,
  }) async {
    final response = await _supabase
        .from('stock_movements')
        .select(
          '*, products:product_id(id, code, name, category, brand, model, unit, stock_quantity, minimum_stock, specifications)',
        )
        .not('product_id', 'is', null)
        .order('created_at', ascending: false)
        .limit(limit);

    return List<Map<String, dynamic>>.from(response)
        .map((movement) {
          final product = movement['products'];
          return {
            ...movement,
            'inventory':
                product is Map<String, dynamic>
                    ? _productToStock(product)
                    : null,
          };
        })
        .toList(growable: false);
  }

  /// Supabase RPC `register_product_stock_movement` kullanarak stok girişi/çıkışı kaydeder.
  Future<void> registerStockMovement({
    required String productId,
    required String movementType,
    required int quantity,
    String? reason,
    String? destination,
    String? note,
  }) async {
    if (movementType != 'in' && movementType != 'out') {
      throw Exception('Geçersiz stok hareketi tipi (in/out olmalı).');
    }

    if (quantity <= 0) {
      throw Exception('Miktar 0\'dan büyük olmalıdır.');
    }

    await _supabase.rpc(
      'register_product_stock_movement',
      params: {
        'p_product_id': productId,
        'p_movement_type': movementType,
        'p_quantity': quantity,
        'p_reason': reason,
        'p_destination': destination,
        'p_note': note,
      },
    );
  }

  // --- ZİMMET YÖNETİMİ (PERSONNEL LOANS) ---

  /// Açık personel zimmetlerini getirir.
  Future<List<Map<String, dynamic>>> getOpenPersonnelLoans() async {
    final response = await _supabase
        .from('product_stock_loans')
        .select(
          '*, products:product_id(id, code, name, category, brand, model, unit, stock_quantity, minimum_stock, stock_tracking_started, specifications)',
        )
        .eq('status', 'borrowed')
        .order('borrowed_at', ascending: false);

    return List<Map<String, dynamic>>.from(response)
        .map((loan) {
          final product = loan['products'];
          return {
            ...loan,
            'inventory':
                product is Map<String, dynamic>
                    ? _productToStock(product)
                    : null,
          };
        })
        .toList(growable: false);
  }

  /// Stok zimmeti verilebilecek yetkili personeli listeler (RPC).
  Future<List<Map<String, dynamic>>> listStockPersonnel() async {
    try {
      final response = await _supabase.rpc('list_stock_personnel');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Stok personeli listeleme hatası: $e');
      return [];
    }
  }

  /// Supabase RPC `register_product_stock_loan` kullanarak personele zimmet verir.
  Future<void> registerPersonnelLoan({
    required String productId,
    required String personnelId,
    required int quantity,
    String? note,
  }) async {
    if (quantity <= 0) throw Exception('Miktar 0\'dan büyük olmalıdır.');
    await _supabase.rpc(
      'register_product_stock_loan',
      params: {
        'p_product_id': productId,
        'p_personnel_id': personnelId,
        'p_quantity': quantity,
        'p_note': note,
      },
    );
  }

  /// Supabase RPC `close_product_stock_loan` kullanarak zimmeti kapatır (iade / tüketildi).
  Future<void> closePersonnelLoan({
    required int loanId,
    required String resolution,
  }) async {
    if (resolution != 'returned' && resolution != 'consumed') {
      throw Exception('Geçersiz kapatma türü (returned/consumed olmalı).');
    }
    await _supabase.rpc(
      'close_product_stock_loan',
      params: {'p_loan_id': loanId, 'p_resolution': resolution},
    );
  }

  // --- TICKET PARTS (İş Emrinde Kullanılan Malzemeler) ---

  /// İş emrine parça ekler ve stoktan düşer
  Future<void> addPartToTicket(
    String ticketId,
    String productId,
    int quantity,
  ) async {
    final inv =
        await _supabase
            .from(_table)
            .select('stock_quantity')
            .eq('id', productId)
            .single();
    final currentQty = (inv['stock_quantity'] as num?)?.toInt() ?? 0;

    if (currentQty < quantity) {
      throw Exception('Stok yetersiz! Mevcut stok: $currentQty');
    }

    await _supabase.from('ticket_parts').insert({
      'ticket_id': ticketId,
      'product_id': productId,
      'quantity': quantity,
    });

    await updateQuantity(productId, currentQty - quantity);
  }

  /// İş emrinden parça siler ve stoğa iade eder
  Future<void> removePartFromTicket(int partId) async {
    final part =
        await _supabase
            .from('ticket_parts')
            .select('product_id, quantity')
            .eq('id', partId)
            .single();

    final productId = part['product_id']?.toString() ?? '';
    final qty = (part['quantity'] as num?)?.toInt() ?? 0;

    await _supabase.from('ticket_parts').delete().eq('id', partId);

    if (productId.isNotEmpty) {
      try {
        final inv =
            await _supabase
                .from(_table)
                .select('stock_quantity')
                .eq('id', productId)
                .single();
        final currentQty = (inv['stock_quantity'] as num?)?.toInt() ?? 0;
        await updateQuantity(productId, currentQty + qty);
      } catch (e) {
        debugPrint('Stok iade edilirken hata (Ürün silinmiş olabilir): $e');
      }
    }
  }

  /// İş emrine ait parçaları çeker.
  Future<List<TicketPart>> getTicketParts(String ticketId) async {
    final response = await _supabase
        .from('ticket_parts')
        .select('*, products(name, category)')
        .eq('ticket_id', ticketId)
        .order('created_at', ascending: true);

    return (response as List).map((e) => TicketPart.fromJson(e)).toList();
  }

  // --- İŞ EMRİ KULLANIM PROCESSİ ---

  Future<String?> decreaseStockByName(
    String productName, {
    int amount = 1,
  }) async {
    try {
      final response =
          await _supabase
              .from(_table)
              .select()
              .eq('name', productName)
              .maybeSingle();

      if (response == null) {
        debugPrint('Stokta hiç yok (Tanımsız): $productName');
        return productName;
      }

      final currentQty = (response['stock_quantity'] as num?)?.toInt() ?? 0;
      final newQty = currentQty - amount;

      await updateQuantity(response['id'].toString(), newQty);

      if (newQty < 0) return productName;
      return null;
    } catch (e) {
      debugPrint('Stok düşme hatası ($productName): $e');
      return productName;
    }
  }

  Future<void> increaseStockByName(String productName, {int amount = 1}) async {
    try {
      final response =
          await _supabase
              .from(_table)
              .select()
              .eq('name', productName)
              .maybeSingle();

      if (response == null) return;

      final currentQty = (response['stock_quantity'] as num?)?.toInt() ?? 0;
      final newQty = currentQty + amount;

      await updateQuantity(response['id'].toString(), newQty);
    } catch (e) {
      debugPrint('Stok iade hatası ($productName): $e');
    }
  }

  Future<List<String>> processTicketStockUsage({
    String? plcModel,
    String? aspiratorBrand,
    String? aspiratorModel,
    double? aspiratorKw,
    String? vantBrand,
    String? vantModel,
    double? vantKw,
    String? hmiBrand,
    double? hmiSize,
  }) async {
    final List<String> missingItems = [];

    if (plcModel != null && plcModel.isNotEmpty && plcModel != 'Diğer') {
      final name = '$plcModel PLC';
      final result = await decreaseStockByName(name);
      if (result != null) missingItems.add(result);
    }

    if (aspiratorBrand != null &&
        aspiratorKw != null &&
        aspiratorBrand != 'Diğer') {
      final kwStr = formatKw(aspiratorKw);
      final name =
          (aspiratorModel != null && aspiratorModel.isNotEmpty)
              ? '$aspiratorBrand $aspiratorModel $kwStr kW Sürücü'
              : '$aspiratorBrand $kwStr kW Sürücü';
      final result = await decreaseStockByName(name);
      if (result != null) missingItems.add(result);
    }

    if (vantBrand != null && vantKw != null && vantBrand != 'Diğer') {
      final kwStr = formatKw(vantKw);
      final name =
          (vantModel != null && vantModel.isNotEmpty)
              ? '$vantBrand $vantModel $kwStr kW Sürücü'
              : '$vantBrand $kwStr kW Sürücü';
      final result = await decreaseStockByName(name);
      if (result != null) missingItems.add(result);
    }

    if (hmiBrand != null && hmiSize != null && hmiBrand != 'Diğer') {
      final inchStr = formatInch(hmiSize);
      final name = '$hmiBrand $inchStr inç HMI';
      final result = await decreaseStockByName(name);
      if (result != null) missingItems.add(result);
    }

    return missingItems;
  }

  Future<void> revertTicketStockUsage({
    String? plcModel,
    String? aspiratorBrand,
    String? aspiratorModel,
    double? aspiratorKw,
    String? vantBrand,
    String? vantModel,
    double? vantKw,
    String? hmiBrand,
    double? hmiSize,
  }) async {
    if (plcModel != null && plcModel.isNotEmpty && plcModel != 'Diğer') {
      await increaseStockByName('$plcModel PLC');
    }

    if (aspiratorBrand != null &&
        aspiratorKw != null &&
        aspiratorBrand != 'Diğer') {
      final kwStr = formatKw(aspiratorKw);
      final name =
          (aspiratorModel != null && aspiratorModel.isNotEmpty)
              ? '$aspiratorBrand $aspiratorModel $kwStr kW Sürücü'
              : '$aspiratorBrand $kwStr kW Sürücü';
      await increaseStockByName(name);
    }

    if (vantBrand != null && vantKw != null && vantBrand != 'Diğer') {
      final kwStr = formatKw(vantKw);
      final name =
          (vantModel != null && vantModel.isNotEmpty)
              ? '$vantBrand $vantModel $kwStr kW Sürücü'
              : '$vantBrand $kwStr kW Sürücü';
      await increaseStockByName(name);
    }

    if (hmiBrand != null && hmiSize != null && hmiBrand != 'Diğer') {
      final inchStr = formatInch(hmiSize);
      await increaseStockByName('$hmiBrand $inchStr inç HMI');
    }
  }

  // --- MARKA MODELLERİ YÖNETİMİ ---

  Future<void> initializeDefaultBrands() async {
    await _ensureCategoryDefaults('PLC', plcModels);
    await _ensureCategoryDefaults('HMI', hmiBrands);
  }

  Future<void> _ensureCategoryDefaults(
    String category,
    List<String> defaults,
  ) async {
    try {
      final response = await _supabase
          .from('brand_models')
          .select('id')
          .eq('category', category)
          .limit(1);

      if ((response as List).isEmpty) {
        for (var brand in defaults) {
          if (brand == 'Diğer') continue;
          try {
            await addBrand(brand, category);
          } catch (_) {}
        }
      }
    } catch (e) {
      debugPrint('$category varsayılanları yükleme hatası: $e');
    }
  }

  Future<List<String>> getBrandModels(String brandName, String category) async {
    try {
      final response = await _supabase
          .from('brand_models')
          .select('model_name')
          .eq('brand_name', brandName)
          .eq('category', category)
          .order('model_name', ascending: true);

      return (response as List).map((e) => e['model_name'] as String).toList();
    } catch (e) {
      debugPrint('Marka modelleri çekme hatası ($brandName, $category): $e');
      return [];
    }
  }

  Future<List<String>> getBrandsByCategory(String category) async {
    try {
      final response = await _supabase
          .from('brand_models')
          .select('brand_name')
          .eq('category', category)
          .eq('model_name', '')
          .order('brand_name', ascending: true);

      return (response as List).map((e) => e['brand_name'] as String).toList();
    } catch (e) {
      debugPrint('Kategori markaları çekme hatası ($category): $e');
      return [];
    }
  }

  Future<void> addBrand(String brandName, String category) async {
    try {
      final existing = await _supabase
          .from('brand_models')
          .select('id')
          .eq('brand_name', brandName)
          .eq('category', category)
          .limit(1);

      if ((existing as List).isEmpty) {
        await _supabase.from('brand_models').insert({
          'brand_name': brandName.trim(),
          'category': category,
          'model_name': '',
        });
      }
    } catch (e) {
      debugPrint('Marka ekleme hatası: $e');
      rethrow;
    }
  }

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

  Future<List<Map<String, dynamic>>> getAllBrandModels() async {
    try {
      final response = await _supabase
          .from('brand_models')
          .select()
          .neq('model_name', '')
          .order('category', ascending: true)
          .order('brand_name', ascending: true)
          .order('model_name', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Tüm marka modelleri çekme hatası: $e');
      return [];
    }
  }

  Future<Map<String, List<String>>> getAllBrands() async {
    try {
      final response = await _supabase
          .from('brand_models')
          .select('brand_name, category')
          .eq('model_name', '')
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

  Future<void> addBrandModel(
    String brandName,
    String modelName,
    String category,
  ) async {
    try {
      final trimmedModelName = modelName.trim();
      if (trimmedModelName.isEmpty) {
        throw Exception('Model adı boş olamaz');
      }

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

  Future<void> deleteBrandModel(int id) async {
    try {
      await _supabase.from('brand_models').delete().eq('id', id);
    } catch (e) {
      debugPrint('Marka modeli silme hatası: $e');
      rethrow;
    }
  }
}
