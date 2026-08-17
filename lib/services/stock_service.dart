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
    final rawName = (product['name'] ?? '').toString();
    final rawCode = (product['code'] ?? '').toString();
    final category = (product['category'] ?? '').toString();
    final brand = (product['brand'] ?? '').toString();
    final model = (product['model'] ?? '').toString();

    final formatted = formatProductName(
      rawName: rawName,
      code: rawCode,
      category: category,
      brand: brand,
      model: model,
    );

    return {
      ...product,
      'displayName': formatted['title'],
      'displaySubtitle': formatted['subtitle'],
      'quantity': (product['stock_quantity'] as num?)?.toInt() ?? 0,
      'critical_level': (product['minimum_stock'] as num?)?.toInt() ?? 0,
      'stock_tracking_started': product['stock_tracking_started'] == true,
      'barcode': specifications['barcode'] ?? product['code'] ?? '',
      'shelf_location': specifications['shelf_location'] ?? '',
    };
  }

  /// Ham katalog isimlerini ve teknik özellikleri akıllı ve anlaşılır Türkçe isimlere dönüştürür.
  static Map<String, String> formatProductName({
    required String rawName,
    required String code,
    String? category,
    String? brand,
    String? model,
  }) {
    var name = rawName.trim();

    // Ürün adı ürün koduyla başlıyorsa veya aynısıysa temizle
    if (code.isNotEmpty) {
      name =
          name
              .replaceAll(RegExp(RegExp.escape(code), caseSensitive: false), '')
              .trim();
    }
    name =
        name
            .replaceFirst(RegExp(r'^[-_\s:]+'), '')
            .replaceFirst(RegExp(r'[-_\s:]+$'), '')
            .trim();

    // Eğer ürün adı ham teknik özellik listesiyse (Örn: "16UIO,4CHO,4Rel,RJ45...")
    final isRawTechnicalSpecs = name.contains(
      RegExp(
        r'\d+UIO|\d+CHO|\d+Rel|RJ45|Sylk|230V|DN\d+|PN\d+',
        caseSensitive: false,
      ),
    );

    String title = '';
    String subtitle = '';

    if (isRawTechnicalSpecs || name.isEmpty) {
      final b = (brand != null && brand.isNotEmpty) ? brand : '';
      final c =
          (category != null && category.isNotEmpty && category != 'Diğer')
              ? category
              : 'Ürün / Cihaz';
      final m =
          (model != null && model.isNotEmpty && model != code) ? model : '';
      title = '$b $c $m'.replaceAll(RegExp(r'\s+'), ' ').trim();
      if (title.isEmpty) title = code.isNotEmpty ? code : 'İsimsiz Ürün';
      subtitle = name; // Ham özellikleri alt bilgiye koy
    } else {
      title = name;
    }

    return {'title': title, 'subtitle': subtitle};
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
    'Zone Controllers',
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

  /// Stok ürünlerini çeker.
  Future<List<Map<String, dynamic>>> getStocks({
    bool onlyTracked = true,
  }) async {
    const pageSize = 500;
    final stocks = <Map<String, dynamic>>[];
    var offset = 0;
    while (true) {
      var query = _supabase.from(_table).select();

      if (onlyTracked) {
        query = query.eq('stock_tracking_started', true);
      }

      final response = await query
          .order('name', ascending: true)
          .range(offset, offset + pageSize - 1);

      final page = List<Map<String, dynamic>>.from(response);
      stocks.addAll(page.map(_productToStock));
      if (page.length < pageSize) break;
      offset += pageSize;
    }
    return stocks;
  }

  /// Katalogdaki ürünleri aramak için kullanılır (Fiyat teklifi kataloğu).
  Future<List<Map<String, dynamic>>> getCatalogProducts({
    String? search,
    String? category,
  }) async {
    var query = _supabase.from(_table).select();
    if (category != null && category.isNotEmpty && category != 'Tümü') {
      query = query.eq('category', category);
    }
    final response = await query.order('name', ascending: true).limit(300);
    final products =
        List<Map<String, dynamic>>.from(response).map(_productToStock).toList();

    if (search != null && search.trim().isNotEmpty) {
      final q = search.trim().toLowerCase();
      return products.where((p) {
        final code = (p['code'] ?? '').toString().toLowerCase();
        final name = (p['name'] ?? '').toString().toLowerCase();
        final displayName = (p['displayName'] ?? '').toString().toLowerCase();
        final brand = (p['brand'] ?? '').toString().toLowerCase();
        return code.contains(q) ||
            name.contains(q) ||
            displayName.contains(q) ||
            brand.contains(q);
      }).toList();
    }

    return products;
  }

  /// Katalogdaki bir ürün için stok takibini başlatır ve depoya giriş hareketi kaydeder.
  Future<void> startStockTracking({
    required String productId,
    required int initialQuantity,
    int minimumStock = 0,
    String? shelfLocation,
    String? barcode,
  }) async {
    final current =
        await _supabase
            .from(_table)
            .select('specifications')
            .eq('id', productId)
            .single();

    final specifications = Map<String, dynamic>.from(
      current['specifications'] as Map? ?? const <String, dynamic>{},
    );

    if (shelfLocation != null && shelfLocation.trim().isNotEmpty) {
      specifications['shelf_location'] = shelfLocation.trim();
    }
    if (barcode != null && barcode.trim().isNotEmpty) {
      specifications['barcode'] = barcode.trim();
    }

    await _supabase
        .from(_table)
        .update({
          'stock_tracking_started': true,
          'minimum_stock': minimumStock,
          'specifications': specifications,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', productId);

    if (initialQuantity > 0) {
      await registerStockMovement(
        productId: productId,
        movementType: 'in',
        quantity: initialQuantity,
        reason: 'Stok takibi başlatıldı / İlk depo girişi',
      );
    }
  }

  /// Stok takibini kapatır (GÜVENLİ: Fiyat teklifleri kataloğundaki ürün asla silinmez!).
  Future<void> stopStockTracking(String productId) async {
    await _supabase
        .from(_table)
        .update({
          'stock_tracking_started': false,
          'stock_quantity': 0,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', productId);
  }

  /// Stok takibini durdurur (deleteStock geriye uyumluluk adapter'ı).
  Future<void> deleteStock(String id) async {
    await stopStockTracking(id);
  }

  /// Veritabanındaki tüm sanal katalog stoklarını temizler ve depoyu sıfırlar.
  Future<void> resetCatalogStockTracking() async {
    await _supabase
        .from(_table)
        .update({
          'stock_tracking_started': false,
          'stock_quantity': 0,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('stock_tracking_started', true);
  }

  /// Barkod veya ürün koduna göre tek ürün getirir.
  Future<Map<String, dynamic>?> getStockByBarcode(String barcode) async {
    final normalized = barcode.trim();
    if (normalized.isEmpty) return null;
    final stocks = await getStocks(onlyTracked: false);
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

  /// Aktif iş emirlerini (İş Kodu + Müşteri Adı + Başlık) getirir.
  Future<List<Map<String, dynamic>>> getActiveTicketsList() async {
    try {
      final response = await _supabase
          .from('tickets')
          .select('id, job_code, title, customers(name)')
          .order('created_at', ascending: false)
          .limit(100);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Aktif iş emirleri çekme hatası: $e');
      return [];
    }
  }

  /// Sıfırdan özel ürün stok kaydı oluşturur ve stok takibini başlatır.
  Future<void> addStock(Map<String, dynamic> data) async {
    final now = DateTime.now().toUtc();
    final token = now.microsecondsSinceEpoch.toString();
    await _supabase.from(_table).insert({
      'id': 'stock-$token',
      'code': 'STK-$token',
      'brand': data['brand'] ?? '',
      'model': data['model'] ?? '',
      'stock_tracking_started': true,
      ..._stockDataToProduct(data),
    });

    final qty = (data['quantity'] as num?)?.toInt() ?? 0;
    if (qty > 0) {
      await registerStockMovement(
        productId: 'stock-$token',
        movementType: 'in',
        quantity: qty,
        reason: 'Yeni özel ürün açılışı / İlk stok girişi',
      );
    }
  }

  /// Stok kaydını günceller ve miktar değişikliği varsa otomatik hareket logu üretir.
  Future<void> updateStock(String id, Map<String, dynamic> data) async {
    final current =
        await _supabase
            .from(_table)
            .select('specifications, stock_quantity, name')
            .eq('id', id)
            .single();

    final oldQty = (current['stock_quantity'] as num?)?.toInt() ?? 0;
    await _supabase
        .from(_table)
        .update(_stockDataToProduct(data, current: current))
        .eq('id', id);

    if (data.containsKey('quantity')) {
      final newQty = (data['quantity'] as num?)?.toInt() ?? oldQty;
      if (newQty != oldQty) {
        final diff = newQty - oldQty;
        final isIn = diff > 0;
        final actor = _supabase.auth.currentUser;
        try {
          await _supabase.from('stock_movements').insert({
            'product_id': id,
            'movement_type': isIn ? 'in' : 'out',
            'quantity': diff.abs(),
            'quantity_before': oldQty,
            'quantity_after': newQty,
            'reason': 'Stok kartı düzenleme / Miktar düzeltme',
            'destination': 'Depo',
            'note': 'Kullanıcı tarafından elle güncellendi',
            'created_by': actor?.id,
          });
        } catch (e) {
          debugPrint('Stok güncelleme log hatası: $e');
        }
      }
    }
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

  /// Stok miktarını günceller ve hareket logu kaydeder.
  Future<void> updateQuantity(
    String id,
    int newQuantity, {
    String? reason,
    String? destination,
    String? note,
    String? serialNumber,
    String? jobCode,
  }) async {
    final current =
        await _supabase
            .from(_table)
            .select('stock_quantity')
            .eq('id', id)
            .single();
    final oldQty = (current['stock_quantity'] as num?)?.toInt() ?? 0;

    await _supabase
        .from(_table)
        .update({
          'stock_quantity': newQuantity,
          'stock_tracking_started': true,
          'updated_at': DateTime.now().toUtc().toIso8601String(),
        })
        .eq('id', id);

    if (newQuantity != oldQty) {
      final diff = newQuantity - oldQty;
      final actor = _supabase.auth.currentUser;
      try {
        await _supabase.from('stock_movements').insert({
          'product_id': id,
          'movement_type': diff > 0 ? 'in' : 'out',
          'quantity': diff.abs(),
          'quantity_before': oldQty,
          'quantity_after': newQuantity,
          'reason': reason ?? 'Stok miktarı güncellendi',
          'destination': destination,
          'note': note,
          'serial_number': serialNumber,
          'job_code': jobCode,
          'created_by': actor?.id,
        });
      } catch (e) {
        debugPrint('Stok miktar hareket logu hatası: $e');
      }
    }
  }

  // --- STOCK MOVEMENTS (STOK HAREKETLERİ) ---

  Future<List<Map<String, dynamic>>> getStockMovements({
    int limit = 200,
  }) async {
    final response = await _supabase
        .from('stock_movements')
        .select(
          '*, products:product_id(id, code, name, category, brand, model, unit, stock_quantity, minimum_stock, specifications), profiles:created_by(id, full_name, email, role)',
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

  Future<void> registerStockMovement({
    required String productId,
    required String movementType,
    required int quantity,
    String? reason,
    String? destination,
    String? note,
    String? serialNumber,
    String? jobCode,
  }) async {
    if (movementType != 'in' && movementType != 'out') {
      throw Exception('Geçersiz stok hareketi tipi (in/out olmalı).');
    }

    if (quantity <= 0) {
      throw Exception('Miktar 0\'dan büyük olmalıdır.');
    }

    try {
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
    } catch (e) {
      debugPrint('RPC movement failed, using direct fallback: $e');
      final current =
          await _supabase
              .from(_table)
              .select('stock_quantity')
              .eq('id', productId)
              .single();
      final oldQty = (current['stock_quantity'] as num?)?.toInt() ?? 0;
      final newQty =
          movementType == 'in' ? oldQty + quantity : oldQty - quantity;
      if (newQty < 0) throw Exception('Stok yetersiz! Mevcut: $oldQty');

      await updateQuantity(
        productId,
        newQty,
        reason: reason,
        destination: destination,
        note: note,
        serialNumber: serialNumber,
        jobCode: jobCode,
      );
    }
  }

  // --- ZİMMET YÖNETİMİ (PERSONNEL LOANS) ---

  Future<List<Map<String, dynamic>>> getOpenPersonnelLoans() async {
    try {
      await _supabase
          .from('product_stock_loans')
          .update({
            'status': 'returned',
            'quantity': 0,
            'closed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('status', 'borrowed')
          .lte('quantity', 0);
    } catch (e) {
      debugPrint('Sıfır zimmet temizleme hatası: $e');
    }

    final response = await _supabase
        .from('product_stock_loans')
        .select(
          '*, products:product_id(id, code, name, category, brand, model, unit, stock_quantity, minimum_stock, stock_tracking_started, specifications), profiles:personnel_id(id, full_name, email, phone, role)',
        )
        .eq('status', 'borrowed')
        .gt('quantity', 0)
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

  Future<List<Map<String, dynamic>>> listStockPersonnel() async {
    try {
      final response = await _supabase.rpc('list_stock_personnel');
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Stok personeli listeleme hatası: $e');
      try {
        final fallback = await _supabase
            .from('profiles')
            .select('id, email, full_name, role, phone')
            .not('role', 'in', ['pending', 'partner_user', 'partner'])
            .order('full_name', ascending: true);
        return List<Map<String, dynamic>>.from(fallback);
      } catch (_) {
        return [];
      }
    }
  }

  /// Çoklu seri numarasıyla personelin üzerine tekil satırlar (row-by-row) halinde zimmet kaydeder.
  Future<String> registerBatchSerialLoans({
    required String productId,
    required String personnelId,
    required List<String> serialNumbers,
    String? jobCode,
    String? note,
  }) async {
    final validSerials =
        serialNumbers.map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
    if (validSerials.isEmpty) {
      throw Exception('Lütfen en az 1 adet seri numarası giriniz.');
    }

    final totalQty = validSerials.length;
    final current =
        await _supabase
            .from(_table)
            .select('stock_quantity, name')
            .eq('id', productId)
            .single();
    final curQty = (current['stock_quantity'] as num?)?.toInt() ?? 0;
    if (curQty < totalQty) {
      throw Exception(
        'Stok yetersiz! Mevcut stok: $curQty, Zimmetlenmek istenen: $totalQty',
      );
    }

    try {
      final rpcRes = await _supabase.rpc(
        'register_serial_stock_loans',
        params: {
          'p_product_id': productId,
          'p_personnel_id': personnelId,
          'p_serial_numbers': validSerials,
          'p_job_code': jobCode,
          'p_note': note,
        },
      );
      return rpcRes?.toString() ?? 'BATCH-OK';
    } catch (e) {
      debugPrint(
        'RPC register_serial_stock_loans failed, executing direct batch fallback: $e',
      );
      final batchId = 'BATCH-${DateTime.now().millisecondsSinceEpoch}';
      final profile =
          await _supabase
              .from('profiles')
              .select('full_name, email')
              .eq('id', personnelId)
              .single();
      final personnelName =
          (profile['full_name']?.toString().trim().isNotEmpty == true)
              ? profile['full_name'].toString()
              : (profile['email'] ?? 'Personel');
      final actorId = _supabase.auth.currentUser?.id;

      // 1. Depo stok miktarını düşür
      final newQty = curQty - totalQty;
      await _supabase
          .from(_table)
          .update({
            'stock_quantity': newQty,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', productId);

      // 2. Her seri no için tek tek satır oluştur
      for (final sn in validSerials) {
        await _supabase.from('product_stock_loans').insert({
          'product_id': productId,
          'personnel_id': personnelId,
          'personnel_name': personnelName,
          'quantity': 1,
          'serial_number': sn,
          'loan_batch_id': batchId,
          'job_code': jobCode?.trim().isEmpty == true ? null : jobCode?.trim(),
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
          'status': 'borrowed',
          'borrowed_at': DateTime.now().toUtc().toIso8601String(),
          'created_by': actorId,
        });

        await _supabase.from('stock_movements').insert({
          'product_id': productId,
          'movement_type': 'out',
          'quantity': 1,
          'quantity_before': curQty,
          'quantity_after': newQty,
          'reason': 'Personele zimmetlendi (Seri No: $sn)',
          'destination': personnelName,
          'note': note?.trim().isEmpty == true ? null : note?.trim(),
          'serial_number': sn,
          'job_code': jobCode?.trim().isEmpty == true ? null : jobCode?.trim(),
          'created_by': actorId,
        });
      }

      return batchId;
    }
  }

  Future<void> registerPersonnelLoan({
    required String productId,
    required String personnelId,
    required int quantity,
    String? serialNumber,
    String? jobCode,
    String? note,
  }) async {
    if (quantity <= 0) throw Exception('Miktar 0\'dan büyük olmalıdır.');

    if (serialNumber != null && serialNumber.trim().isNotEmpty) {
      await registerBatchSerialLoans(
        productId: productId,
        personnelId: personnelId,
        serialNumbers: [serialNumber.trim()],
        jobCode: jobCode,
        note: note,
      );
      return;
    }

    final noteText =
        [
          if (jobCode != null && jobCode.isNotEmpty) '[İş Kodu: $jobCode]',
          if (note != null && note.isNotEmpty) note,
        ].join(' ').trim();

    try {
      await _supabase.rpc(
        'register_product_stock_loan',
        params: {
          'p_product_id': productId,
          'p_personnel_id': personnelId,
          'p_quantity': quantity,
          'p_note': noteText.isNotEmpty ? noteText : null,
        },
      );
    } catch (e) {
      debugPrint('RPC fallback loan: $e');
      final current =
          await _supabase
              .from(_table)
              .select('stock_quantity')
              .eq('id', productId)
              .single();
      final curQty = (current['stock_quantity'] as num?)?.toInt() ?? 0;
      if (curQty < quantity)
        throw Exception('Stok yetersiz! Mevcut stok: $curQty');

      final profile =
          await _supabase
              .from('profiles')
              .select('full_name, email')
              .eq('id', personnelId)
              .single();
      final personnelName =
          (profile['full_name']?.toString().trim().isNotEmpty == true)
              ? profile['full_name'].toString()
              : (profile['email'] ?? 'Personel');
      final actorId = _supabase.auth.currentUser?.id;

      final newQty = curQty - quantity;
      await updateQuantity(productId, newQty);

      await _supabase.from('product_stock_loans').insert({
        'product_id': productId,
        'personnel_id': personnelId,
        'personnel_name': personnelName,
        'quantity': quantity,
        'job_code': jobCode,
        'note': noteText.isNotEmpty ? noteText : null,
        'status': 'borrowed',
        'borrowed_at': DateTime.now().toUtc().toIso8601String(),
        'created_by': actorId,
      });

      await _supabase.from('stock_movements').insert({
        'product_id': productId,
        'movement_type': 'out',
        'quantity': quantity,
        'quantity_before': curQty,
        'quantity_after': newQty,
        'reason': 'Personele verildi',
        'destination': personnelName,
        'note': noteText.isNotEmpty ? noteText : null,
        'job_code': jobCode,
        'created_by': actorId,
      });
    }
  }

  /// Zimmet kapatma veya zimmet dönüşü işlemlerde depo stoğundan mükerrer düşüm yapmadan sadece audit logu tutan yardımcı metod.
  Future<void> logStockMovementAudit({
    required String productId,
    required String movementType,
    required int quantity,
    String? reason,
    String? destination,
    String? note,
    String? serialNumber,
    String? jobCode,
  }) async {
    try {
      final current =
          await _supabase
              .from(_table)
              .select('stock_quantity')
              .eq('id', productId)
              .maybeSingle();
      final curQty = (current?['stock_quantity'] as num?)?.toInt() ?? 0;
      final actorId = _supabase.auth.currentUser?.id;

      await _supabase.from('stock_movements').insert({
        'product_id': productId,
        'movement_type': movementType,
        'quantity': quantity,
        'quantity_before': curQty,
        'quantity_after': curQty,
        'reason': reason,
        'destination': destination,
        'note': note,
        'serial_number': serialNumber,
        'job_code': jobCode,
        'created_by': actorId,
      });
    } catch (e) {
      debugPrint('Stok hareket audit log hatası: $e');
    }
  }

  /// Checklist ile seçilen zimmet kayıtlarını kapatır:
  /// - Seçilenler -> 'consumed' (Sarf edildi / Projede kullanıldı)
  /// - Seçilmeyenler (veya iade olarak belirtilenler) -> 'returned' (Depoya sağlam iade, stok +1 artar)
  Future<void> processLoanChecklistResolution({
    required List<int> consumedLoanIds,
    required List<int> returnedLoanIds,
    List<Map<String, dynamic>> defectiveLoans = const [],
    required String personnelName,
    String? jobCode,
    String? note,
  }) async {
    final nowUtc = DateTime.now().toUtc().toIso8601String();
    final actorId = _supabase.auth.currentUser?.id;

    // 1. Sarf Edilenleri Kapat (consumed)
    for (final loanId in consumedLoanIds) {
      final loan =
          await _supabase
              .from('product_stock_loans')
              .select()
              .eq('id', loanId)
              .maybeSingle();
      if (loan == null) continue;
      final prodId = loan['product_id'].toString();
      final sn = loan['serial_number']?.toString();

      await _supabase
          .from('product_stock_loans')
          .update({
            'status': 'consumed',
            'closed_at': nowUtc,
            'closed_by': actorId,
            'job_code': jobCode ?? loan['job_code'],
          })
          .eq('id', loanId);

      await logStockMovementAudit(
        productId: prodId,
        movementType: 'out',
        quantity: (loan['quantity'] as num?)?.toInt() ?? 1,
        reason: 'Zimmetten sarf edildi (Seri No: ${sn ?? '-'})',
        destination: jobCode ?? personnelName,
        note: note ?? loan['note'],
        serialNumber: sn,
        jobCode: jobCode ?? loan['job_code'],
      );
    }

    // 2. İade Edilenleri Kapat ve Stoğa Ekle (returned)
    // Ürün bazında kaç adet iade edildiğini topla
    final Map<String, int> returnCountsByProduct = {};
    for (final loanId in returnedLoanIds) {
      final loan =
          await _supabase
              .from('product_stock_loans')
              .select()
              .eq('id', loanId)
              .maybeSingle();
      if (loan == null) continue;
      final prodId = loan['product_id'].toString();
      final sn = loan['serial_number']?.toString();
      final qty = (loan['quantity'] as num?)?.toInt() ?? 1;

      returnCountsByProduct[prodId] =
          (returnCountsByProduct[prodId] ?? 0) + qty;

      await _supabase
          .from('product_stock_loans')
          .update({
            'status': 'returned',
            'closed_at': nowUtc,
            'closed_by': actorId,
          })
          .eq('id', loanId);

      await logStockMovementAudit(
        productId: prodId,
        movementType: 'in',
        quantity: qty,
        reason: 'Personelden depoya sağlam iade (Seri No: ${sn ?? '-'})',
        destination: personnelName,
        note: note ?? loan['note'],
        serialNumber: sn,
        jobCode: jobCode ?? loan['job_code'],
      );
    }

    // Sağlam iade edilen miktarları depo stoğuna tekrar ekle
    for (final entry in returnCountsByProduct.entries) {
      try {
        final inv =
            await _supabase
                .from(_table)
                .select('stock_quantity')
                .eq('id', entry.key)
                .single();
        final curQty = (inv['stock_quantity'] as num?)?.toInt() ?? 0;
        await _supabase
            .from(_table)
            .update({
              'stock_quantity': curQty + entry.value,
              'updated_at': nowUtc,
            })
            .eq('id', entry.key);
      } catch (e) {
        debugPrint('İade stok artırma hatası (${entry.key}): $e');
      }
    }

    // 3. Arızalı Bildirilenleri İşle
    for (final def in defectiveLoans) {
      final loanId = def['loanId'] as int;
      final prodId = def['productId'].toString();
      final sn = def['serialNumber']?.toString();
      final faultDesc =
          def['faultDescription']?.toString() ?? 'Zimmet dönüşü arızalı';

      await _supabase
          .from('product_stock_loans')
          .update({
            'status': 'returned',
            'closed_at': nowUtc,
            'closed_by': actorId,
            'note': '[ARIZALI] $faultDesc',
          })
          .eq('id', loanId);

      await reportDefectiveProduct(
        productId: prodId,
        quantity: 1,
        reportedByName: personnelName,
        faultDescription: 'Seri No: ${sn ?? '-'} - $faultDesc',
        jobCode: jobCode,
        notes: note,
        deductFromWarehouseStock: false,
      );
    }
  }

  // --- PERSONEL KART & DETAY DESTEĞİ ---

  /// Belirli bir personelin tüm açık ve geçmiş zimmetlerini getirir.
  Future<List<Map<String, dynamic>>> getPersonnelLoans(
    String personnelId, {
    bool onlyOpen = false,
  }) async {
    try {
      var query = _supabase
          .from('product_stock_loans')
          .select(
            '*, products:product_id(id, code, name, category, brand, model, unit, stock_quantity, specifications)',
          )
          .eq('personnel_id', personnelId);

      if (onlyOpen) {
        query = query.eq('status', 'borrowed').gt('quantity', 0);
      }

      final response = await query.order('borrowed_at', ascending: false);
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
    } catch (e) {
      debugPrint('Personel zimmetleri çekme hatası: $e');
      return [];
    }
  }

  /// Personelin ilişkili olduğu tüm stok hareket loglarını getirir.
  Future<List<Map<String, dynamic>>> getPersonnelStockMovements(
    String personnelId, {
    String? personnelName,
  }) async {
    try {
      final response = await _supabase
          .from('stock_movements')
          .select(
            '*, products:product_id(id, code, name, category, brand, model, unit), profiles:created_by(id, full_name, email)',
          )
          .or(
            'created_by.eq.$personnelId,destination.ilike.%${personnelName ?? ''}%',
          )
          .order('created_at', ascending: false)
          .limit(100);

      return List<Map<String, dynamic>>.from(response)
          .map((m) {
            final product = m['products'];
            return {
              ...m,
              'inventory':
                  product is Map<String, dynamic>
                      ? _productToStock(product)
                      : null,
            };
          })
          .toList(growable: false);
    } catch (e) {
      debugPrint('Personel hareketleri çekme hatası: $e');
      return [];
    }
  }

  /// Personel Yönetici Notlarını getirir.
  Future<List<Map<String, dynamic>>> getPersonnelNotes(
    String personnelId,
  ) async {
    try {
      final response = await _supabase
          .from('personnel_notes')
          .select('*, profiles:created_by(id, full_name, email, role)')
          .eq('personnel_id', personnelId)
          .order('created_at', ascending: false);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      debugPrint('Personel notları çekme hatası: $e');
      return [];
    }
  }

  /// Personel Yönetici Notu ekler.
  Future<void> addPersonnelNote({
    required String personnelId,
    required String note,
  }) async {
    final actorId = _supabase.auth.currentUser?.id;
    await _supabase.from('personnel_notes').insert({
      'personnel_id': personnelId,
      'note': note.trim(),
      'created_by': actorId,
    });
  }

  /// Personel Yönetici Notu siler.
  Future<void> deletePersonnelNote(int noteId) async {
    await _supabase.from('personnel_notes').delete().eq('id', noteId);
  }

  /// Personel zimmetini esnek sarf (tüketim), iade ve arızalı miktarları ile işler/kapatır.
  Future<void> processPersonnelLoanResolution({
    required int loanId,
    required String productId,
    required String personnelName,
    required int totalLoanQty,
    required int consumedQty,
    required int returnedQty,
    int defectiveQty = 0,
    String? faultDescription,
    String? jobCode,
    String? note,
  }) async {
    final totalAccounted = consumedQty + returnedQty + defectiveQty;
    if (totalAccounted <= 0) {
      throw Exception(
        'Lütfen en az 1 adet sarf, iade veya arızalı miktarı giriniz.',
      );
    }
    if (totalAccounted > totalLoanQty) {
      throw Exception(
        'Sarf ($consumedQty) + İade ($returnedQty) + Arızalı ($defectiveQty) toplam zimmetli miktardan ($totalLoanQty) fazla olamaz.',
      );
    }

    final remainingQty = totalLoanQty - totalAccounted;

    // 1. İade Edilen Miktar -> Depo stokuna tekrar giriş yapılır (fiziksel stoğa geri katılır)
    if (returnedQty > 0) {
      final current =
          await _supabase
              .from(_table)
              .select('stock_quantity')
              .eq('id', productId)
              .single();
      final curQty = (current['stock_quantity'] as num?)?.toInt() ?? 0;
      await updateQuantity(productId, curQty + returnedQty);

      await logStockMovementAudit(
        productId: productId,
        movementType: 'in',
        quantity: returnedQty,
        reason: 'Personelden depoya iade alındı',
        destination: personnelName,
        note: note,
      );
    }

    // 2. Sarf Edilen Miktar -> Zimmet verilirken fiziksel stoktan zaten düşüldüğü için tekrar stok düşülmez, sadece log tutulur
    if (consumedQty > 0) {
      final jobDesc =
          (jobCode != null && jobCode.isNotEmpty)
              ? 'İş Kodu: $jobCode'
              : 'Personel Sarfı';
      await logStockMovementAudit(
        productId: productId,
        movementType: 'out',
        quantity: consumedQty,
        reason: 'Zimmetten sarf edildi ($jobDesc)',
        destination: jobCode ?? personnelName,
        note: note,
      );
    }

    // 3. Arızalı Ayrılan Miktar -> Zimmetten arızalıya ayrıldığı için depo stoğundan mükerrer düşüm YAPILMAZ!
    if (defectiveQty > 0) {
      await reportDefectiveProduct(
        productId: productId,
        quantity: defectiveQty,
        reportedByName: personnelName,
        faultDescription:
            faultDescription ?? 'Zimmet dönüşü arızalı bildirildi',
        jobCode: jobCode,
        notes: note,
        deductFromWarehouseStock:
            false, // Zimmet verilirken zaten düşüldüğü için tekrar düşme!
      );
    }

    // 4. Zimmet Kaydını Güncelle veya Kapat
    if (remainingQty <= 0) {
      final resolution =
          consumedQty > 0 && returnedQty == 0 && defectiveQty == 0
              ? 'consumed'
              : 'returned';
      // quantity güncellemesi yapılmıyor: tabloda check (quantity > 0) kısıtı var,
      // migration ile >= 0 yapılana kadar 0 yazmak constraint ihlali oluşturuyordu.
      // getOpenPersonnelLoans() zaten .gt('quantity', 0) filtresi uyguluyor,
      // bu nedenle status=returned/consumed olan kayıtlar listede zaten görünmez.
      await _supabase
          .from('product_stock_loans')
          .update({
            'status': resolution,
            'closed_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', loanId);
    } else {
      await _supabase
          .from('product_stock_loans')
          .update({
            'quantity': remainingQty,
            'note':
                '[İşlendi: $returnedQty İade / $consumedQty Sarf / $defectiveQty Arızalı] ${note ?? ''}'
                    .trim(),
          })
          .eq('id', loanId);
    }
  }

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

  // --- ARIZALI ÜRÜN VE RMA TAKİBİ (DEFECTIVE PRODUCTS) ---

  /// Arızalı ürün kayıtlarını çeker (varsayılan: sadece aktif takiptedekiler).
  Future<List<Map<String, dynamic>>> getDefectiveProducts({
    bool onlyActive = true,
  }) async {
    try {
      var query = _supabase
          .from('defective_products')
          .select(
            '*, products:product_id(id, code, name, category, brand, model, unit, stock_quantity, specifications)',
          );

      if (onlyActive) {
        query = query.inFilter('status', [
          'in_faulty_stock',
          'shipped_to_supplier',
        ]);
      }

      final response = await query.order('created_at', ascending: false);

      return List<Map<String, dynamic>>.from(response).map((def) {
        final product = def['products'];
        return {
          ...def,
          'inventory':
              product is Map<String, dynamic> ? _productToStock(product) : null,
        };
      }).toList();
    } catch (e) {
      debugPrint('Arızalı ürünler çekme hatası: $e');
      return [];
    }
  }

  /// Yeni arızalı ürün kaydı oluşturur.
  Future<void> reportDefectiveProduct({
    required String productId,
    required int quantity,
    String? reportedByName,
    String? faultDescription,
    String? jobCode,
    String? notes,
    bool deductFromWarehouseStock = true,
  }) async {
    if (quantity <= 0)
      throw Exception('Arızalı miktar 0\'dan büyük olmalıdır.');
    await _supabase.from('defective_products').insert({
      'product_id': productId,
      'reported_by_name': reportedByName,
      'quantity': quantity,
      'fault_description': faultDescription,
      'job_code': jobCode,
      'notes': notes,
      'status': 'in_faulty_stock',
    });

    if (deductFromWarehouseStock) {
      await registerStockMovement(
        productId: productId,
        movementType: 'out',
        quantity: quantity,
        reason: 'Arızalıya ayrıldı (Arızalı Depoda)',
        destination: jobCode ?? reportedByName,
        note: faultDescription,
      );
    } else {
      await logStockMovementAudit(
        productId: productId,
        movementType: 'out',
        quantity: quantity,
        reason: 'Zimmetten arızalıya ayrıldı (Arızalı Depoda)',
        destination: jobCode ?? reportedByName,
        note: faultDescription,
      );
    }
  }

  /// Arızalı ürün durumunu günceller ve kargo / tamir / değişim / hurda hareketini işler.
  Future<void> updateDefectiveStatus({
    required int defectiveId,
    required String newStatus,
    String? trackingNumber,
    String? supplierName,
    String? notes,
    required String productId,
    required int quantity,
  }) async {
    final validStatuses = [
      'in_faulty_stock',
      'shipped_to_supplier',
      'repaired_returned',
      'replaced',
      'scrapped',
    ];

    if (!validStatuses.contains(newStatus)) {
      throw Exception('Geçersiz arızalı ürün durumu.');
    }

    final payload = <String, dynamic>{
      'status': newStatus,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    if (trackingNumber != null && trackingNumber.isNotEmpty) {
      payload['tracking_number'] = trackingNumber;
    }
    if (supplierName != null && supplierName.isNotEmpty) {
      payload['supplier_name'] = supplierName;
    }
    if (notes != null && notes.isNotEmpty) {
      payload['notes'] = notes;
    }

    await _supabase
        .from('defective_products')
        .update(payload)
        .eq('id', defectiveId);

    // Eğer ürün Tamir Edildiyse veya Yenisi Geldiyse -> Tekrar depodaki sağlam stok miktarına katılır!
    if (newStatus == 'repaired_returned' || newStatus == 'replaced') {
      final current =
          await _supabase
              .from(_table)
              .select('stock_quantity')
              .eq('id', productId)
              .single();
      final curQty = (current['stock_quantity'] as num?)?.toInt() ?? 0;
      await updateQuantity(productId, curQty + quantity);

      final statusDesc =
          newStatus == 'repaired_returned'
              ? 'Tedarikçiden tamir edildi - Sağlam depoya eklendi'
              : 'Tedarikçiden yenisi geldi - Sağlam depoya eklendi';

      await registerStockMovement(
        productId: productId,
        movementType: 'in',
        quantity: quantity,
        reason: statusDesc,
        destination: supplierName,
        note: notes,
      );
    }
  }

  // --- TICKET PARTS ---

  Future<void> addPartToTicket(
    String ticketId,
    dynamic productId,
    int quantity,
  ) async {
    final strProductId = productId.toString();
    final inv =
        await _supabase
            .from(_table)
            .select('stock_quantity, name')
            .eq('id', strProductId)
            .single();
    final currentQty = (inv['stock_quantity'] as num?)?.toInt() ?? 0;

    if (currentQty < quantity) {
      throw Exception('Stok yetersiz! Mevcut stok: $currentQty');
    }

    String? jobCode;
    try {
      final t =
          await _supabase
              .from('tickets')
              .select('job_code, title')
              .eq('id', ticketId)
              .maybeSingle();
      jobCode = t?['job_code']?.toString() ?? t?['title']?.toString();
    } catch (_) {}

    await _supabase.from('ticket_parts').insert({
      'ticket_id': ticketId,
      'product_id': strProductId,
      'quantity': quantity,
    });

    await updateQuantity(
      strProductId,
      currentQty - quantity,
      reason: 'İş emrine parça kullanıldı (${jobCode ?? 'İş Emri'})',
      destination: jobCode ?? ticketId,
      jobCode: jobCode,
      note: 'İş emri parça listesine eklendi',
    );
  }

  Future<void> removePartFromTicket(int partId) async {
    final part =
        await _supabase
            .from('ticket_parts')
            .select('product_id, quantity, ticket_id')
            .eq('id', partId)
            .single();

    final productId = part['product_id']?.toString() ?? '';
    final qty = (part['quantity'] as num?)?.toInt() ?? 0;
    final ticketId = part['ticket_id']?.toString();

    String? jobCode;
    if (ticketId != null) {
      try {
        final t =
            await _supabase
                .from('tickets')
                .select('job_code')
                .eq('id', ticketId)
                .maybeSingle();
        jobCode = t?['job_code']?.toString();
      } catch (_) {}
    }

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
        await updateQuantity(
          productId,
          currentQty + qty,
          reason:
              'İş emrinden parça çıkarıldı / İade (${jobCode ?? 'İş Emri'})',
          destination: 'Depo',
          jobCode: jobCode,
          note: 'İş emrinden silinen parça sağlam depoya geri aktarıldı',
        );
      } catch (e) {
        debugPrint('Stok iade edilirken hata: $e');
      }
    }
  }

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
