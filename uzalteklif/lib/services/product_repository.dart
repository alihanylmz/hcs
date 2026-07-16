import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/price_adjustment_rule.dart';
import '../models/product.dart';

class ProductRepository {
  ProductRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static final List<Product> _memoryProducts = [
    ..._baseProducts,
    ..._buildRandomProducts(count: 50),
  ];

  static final List<Product> _baseProducts = [
    Product(
      id: 'product-001',
      code: 'SNS-QAE-2120',
      name: 'Kanal Tipi Sicaklik Sensoru',
      category: 'Sensor',
      brand: 'Siemens',
      model: 'QAE2120.010',
      unit: 'adet',
      currencyCode: 'TL',
      salePrice: 1850,
      stockQuantity: 26,
      minimumStock: 8,
      vatRate: 20,
      leadTime: '2 is gunu',
      description:
          'HVAC uygulamalari icin kanal tipi sicaklik olcumu yapan dayanikli sensor. '
          'Sabit prob uzunlugu ve standart flans bagli govde ile hizli montaj imkani sunar.',
      technicalSummary: 'Olcum araligi -50/+80 C, PT1000, IP54',
      isActive: true,
      updatedAt: DateTime.now().subtract(const Duration(days: 1)),
      specifications: {
        'olculen_parametre': 'Sicaklik',
        'sensor_tipi': 'PT1000 (Class B)',
        'olcum_araligi': '-50 / +80 C',
        'dogruluk': '+/- 0.5 C @ 25 C',
        'tepki_suresi': '12 sn',
        'cikis_sinyali': 'Pasif (PT1000)',
        'besleme_gerilimi': 'Gerekmez (pasif sensor)',
        'baglanti': '2 telli, terminal bloklu',
        'montaj_tipi': 'Kanal / daldirmali flans',
        'koruma_sinifi': 'IP54',
        'calisma_sicakligi': '-30 / +80 C',
        'prob_uzunlugu': '150 mm',
      },
    ),
    Product(
      id: 'product-002',
      code: 'DDC-PXC7-E400',
      name: 'DDC Kontrolor',
      category: 'DDC Kontrolor',
      brand: 'Siemens',
      model: 'PXC7.E400',
      unit: 'adet',
      currencyCode: 'USDTRY',
      salePrice: 420,
      stockQuantity: 7,
      minimumStock: 4,
      vatRate: 20,
      leadTime: '1 hafta',
      description:
          'Bina otomasyonu projeleri icin network destekli merkezi kontrolor. '
          'Desigo PX ailesinin uyumlu uyesi, BACnet IP ve Modbus TCP destekli.',
      technicalSummary: 'BACnet IP, moduler I/O, 24 VAC besleme',
      isActive: true,
      updatedAt: DateTime.now().subtract(const Duration(hours: 8)),
      specifications: {
        'besleme_gerilimi': '24 VAC / 24 VDC',
        'haberlesme_protokolu': 'BACnet IP, Modbus TCP, RS-485',
        'programlama_dili': 'IEC 61131-3, grafik editor (Desigo ABT)',
        'cpu': 'ARM Cortex-A9, 32 MB flash, 64 MB RAM',
        'web_arayuzu': 'Dahili HTML5 panel',
        'gerçek_zaman_saati': 'Pil destekli RTC, 7 gun yedek',
        'dijital_giris': '8 kanal (24 VDC / kuru kontak)',
        'dijital_cikis': '4 kanal role cikisi (2A @ 30 VDC)',
        'analog_giris': '8 kanal universal (0-10V, 4-20mA, PT1000, NTC)',
        'analog_cikis': '4 kanal (0-10V, 4-20mA)',
        'moduler_io': 'TX-I/O genisletme modulleri ile 128 kanala kadar',
        'koruma_sinifi': 'IP20',
        'calisma_sicakligi': '0 / +50 C',
        'montaj': 'DIN ray 35 mm',
      },
    ),
    Product(
      id: 'product-003',
      code: 'INV-3P-11KW',
      name: 'Frekans Inverteri',
      category: 'Inverter',
      brand: 'Delta',
      model: 'CP2000 11kW',
      unit: 'adet',
      currencyCode: 'EURTRY',
      salePrice: 515,
      stockQuantity: 3,
      minimumStock: 5,
      vatRate: 20,
      leadTime: '10 gun',
      description:
          'Pompa ve fan uygulamalari icin 3 faz surucu cozum paketi. '
          'Dahili PID kontrolu, enerji verimli V/F profili ve STO guvenlik fonksiyonu.',
      technicalSummary: '3 faz 380V, 11 kW, dahili PID, Modbus RTU',
      isActive: true,
      updatedAt: DateTime.now().subtract(const Duration(hours: 4)),
      specifications: {
        'besleme_gerilimi': '3x380-480 VAC (3 faz)',
        'besleme_frekansi': '47 Hz - 63 Hz',
        'kontrol_modu': 'V/F, SVC (sensorsuz vektor kontrolu)',
        'frekans_araligi': '0 Hz - 599 Hz',
        'ayir_cozunurlugu': 'Dijital: 0.01 Hz; Analog: Max freq / 2000',
        'asiri_yuk_akim_orani': '%150/60s, %180/10s',
        'hizlanma_yavaslama': '0.1 sn - 3600 sn',
        'dc_frenleme': 'Var (0.1 - 100% DC frenleme)',
        'pid_fonksiyonu': 'Var (dahili pompa/fan PID)',
        'haberlesme': 'Modbus RTU RS-485 (standart), opsiyonel Profibus',
        'koruma_sinifi': 'IP20',
        'dijital_giris': '6 kanal PNP/NPN secilebilir',
        'role_cikis': '2 kanal programlanabilir (240 VAC / 5A)',
        'hizli_puls_giris': '1 kanal (max 33 kHz)',
        'analog_giris': '2 kanal (AI1: 0-10V/0-20mA, AI2: 0-10V)',
        'analog_cikis': '1 kanal (0-20mA veya 0-10V)',
        'guc': '11 kW',
        'nominal_akim': '24 A',
        'fren_direnci': '95 - 1800 W (harici)',
      },
    ),
    Product(
      id: 'product-004',
      code: 'MEC-VLV-2W-65',
      name: 'Iki Yollu Kontrol Vanasi',
      category: 'Mekanik',
      brand: 'Belimo',
      model: 'H650S',
      unit: 'adet',
      currencyCode: 'TL',
      salePrice: 6420,
      stockQuantity: 14,
      minimumStock: 6,
      vatRate: 20,
      leadTime: '3 is gunu',
      description:
          'Sicak ve soguk su hatlari icin kontrol vanasi ve aktuatore uygun govde. '
          'Modulasyon kontrol ile hassas debi ayari saglar.',
      technicalSummary: 'DN65, PN16, sfero dokum, 3 yollu uyumlu seri',
      isActive: true,
      updatedAt: DateTime.now().subtract(const Duration(days: 2)),
      specifications: {
        'nominal_cap': 'DN65',
        'basinc_sinifi': 'PN16',
        'govde_malzemesi': 'Sfero dokum (GJS-400)',
        'baglanti_tipi': 'Flansli (EN 1092-2)',
        'kv_degeri': '63 m3/h (Kvs)',
        'sizdirmazlik': 'Class IV (EN 12266)',
        'karakteristik': 'Esit yuzdeli (EQM)',
      },
    ),
    Product(
      id: 'product-005',
      code: 'AUT-ACT-NM24A',
      name: 'Damper Aktuatoru',
      category: 'Otomasyon',
      brand: 'Belimo',
      model: 'NM24A-SR',
      unit: 'adet',
      currencyCode: 'USDTRY',
      salePrice: 138,
      stockQuantity: 18,
      minimumStock: 6,
      vatRate: 20,
      leadTime: '4 is gunu',
      description:
          'Hava damper uygulamalari icin modulating kontrol destekli aktuator. '
          'Ses seviyesi dusuk, otomatik donus yonu secimi ve el kumandasi dahil.',
      technicalSummary: '10 Nm, 24 VAC/DC, 0-10V kontrol, IP54',
      isActive: true,
      updatedAt: DateTime.now().subtract(const Duration(days: 3)),
      specifications: {
        'tork': '10 Nm',
        'calisma_suresi': '150 sn',
        'yay_donus': 'Yok (motor destekli donus)',
        'besleme_gerilimi': '24 VAC / 24 VDC',
        'kontrol_sinyali': '0-10 V DC (2-10 V secilebilir)',
        'koruma_sinifi': 'IP54',
      },
    ),
  ];

  static List<Product> _buildRandomProducts({required int count}) {
    const categories = [
      'Sensor',
      'Inverter',
      'Mekanik',
      'Otomasyon',
      'Elektrik',
      'Kontrol',
    ];
    const brands = [
      'Siemens',
      'Belimo',
      'Delta',
      'Schneider',
      'Danfoss',
      'Honeywell',
    ];
    const units = ['adet', 'set', 'paket'];
    const leadTimes = ['2 is gunu', '3 is gunu', '1 hafta', '10 gun', '15 gun'];
    const currencies = ['TL', 'USDTRY', 'EURTRY'];
    final random = Random(20260420);

    return List<Product>.generate(count, (index) {
      final category = categories[random.nextInt(categories.length)];
      final brand = brands[random.nextInt(brands.length)];
      final modelCode = 1000 + random.nextInt(9000);
      final stockQuantity = 2 + random.nextInt(58);
      final minimumStock = 2 + random.nextInt(14);
      final price = 70 + random.nextInt(1450) + random.nextDouble();
      final dayOffset = random.nextInt(20);
      final hourOffset = random.nextInt(23);
      final sequence = index + 6;

      return Product(
        id: 'product-${sequence.toString().padLeft(3, '0')}',
        code: '${category.substring(0, 3).toUpperCase()}-$modelCode-$sequence',
        name: '$category Urunu $sequence',
        category: category,
        brand: brand,
        model: '${brand.substring(0, 2).toUpperCase()}-$modelCode',
        unit: units[random.nextInt(units.length)],
        currencyCode: currencies[random.nextInt(currencies.length)],
        salePrice: price,
        stockQuantity: stockQuantity.toDouble(),
        minimumStock: minimumStock.toDouble(),
        vatRate: 20,
        leadTime: leadTimes[random.nextInt(leadTimes.length)],
        description:
            '$brand marka $category urunu, satis ve teklif operasyonlari icin demo kayit.',
        technicalSummary:
            'Model $modelCode, standart saha uyumu, seri no DMO-$sequence',
        isActive: random.nextInt(10) > 0,
        updatedAt: DateTime.now().subtract(
          Duration(days: dayOffset, hours: hourOffset),
        ),
        specifications: _sampleSpecsFor(
          category: category,
          brand: brand,
          modelCode: modelCode,
          random: random,
        ),
      );
    });
  }

  /// Kategoriye gore ornek spesifikasyon seti uretir. Gercek projede bu
  /// alanlar kullanici tarafindan doldurulur; seed verisinde "bos degil,
  /// ornek dolu" bir gorunum saglamak icin bu fonksiyon kullanilir.
  static Map<String, String> _sampleSpecsFor({
    required String category,
    required String brand,
    required int modelCode,
    required Random random,
  }) {
    final cat = category.toLowerCase();
    if (cat == 'inverter') {
      final powers = ['1.5 kW', '2.2 kW', '4 kW', '5.5 kW', '7.5 kW', '11 kW'];
      final power = powers[random.nextInt(powers.length)];
      return {
        'besleme_gerilimi': '3x380-480 VAC',
        'besleme_frekansi': '47 Hz - 63 Hz',
        'kontrol_modu': 'V/F ve SVC',
        'frekans_araligi': '0 Hz - 599 Hz',
        'ayir_cozunurlugu': 'Dijital: 0.01 Hz',
        'asiri_yuk_akim_orani': '%150/60s, %180/10s',
        'hizlanma_yavaslama': '0.1 sn - 3600 sn',
        'dc_frenleme': 'Var',
        'pid_fonksiyonu': 'Var',
        'haberlesme': 'Modbus RTU (RS-485)',
        'koruma_sinifi': 'IP20',
        'dijital_giris': '4 kanal PNP/NPN',
        'role_cikis': '2 kanal programlanabilir',
        'analog_giris': '2 kanal (0-10V / 4-20mA)',
        'analog_cikis': '1 kanal (0-10V / 4-20mA)',
        'guc': power,
        'nominal_akim': '${(random.nextInt(15) + 5)} A',
      };
    }
    if (cat == 'sensor') {
      return {
        'olculen_parametre': 'Sicaklik',
        'sensor_tipi': 'PT1000 (Class B)',
        'olcum_araligi': '-30 / +120 C',
        'dogruluk': '+/- 0.5 C',
        'tepki_suresi': '15 sn',
        'cikis_sinyali': 'Pasif (PT1000) / 4-20 mA',
        'besleme_gerilimi': '24 VAC/DC',
        'baglanti': '2 telli',
        'montaj_tipi': 'Kanal tipi / daldirmali',
        'koruma_sinifi': 'IP54',
        'calisma_sicakligi': '-20 / +70 C',
        'prob_uzunlugu': '${[100, 150, 200, 250][random.nextInt(4)]} mm',
      };
    }
    if (cat == 'kontrol') {
      return {
        'besleme_gerilimi': '24 VAC / 24 VDC',
        'haberlesme_protokolu': 'BACnet IP, Modbus TCP',
        'programlama_dili': 'IEC 61131-3',
        'cpu': 'ARM 32-bit, 16 MB flash',
        'web_arayuzu': 'Dahili HTML5',
        'dijital_giris': '8 kanal',
        'dijital_cikis': '4 kanal role',
        'analog_giris': '8 kanal universal',
        'analog_cikis': '4 kanal 0-10V / 4-20mA',
        'moduler_io': 'Genisletme ile 64 kanala kadar',
        'koruma_sinifi': 'IP20',
        'calisma_sicakligi': '0 / +50 C',
        'montaj': 'DIN ray 35 mm',
      };
    }
    if (cat == 'mekanik') {
      final dn = [25, 32, 40, 50, 65, 80, 100][random.nextInt(7)];
      return {
        'nominal_cap': 'DN$dn',
        'basinc_sinifi': 'PN16',
        'govde_malzemesi': 'Sfero dokum',
        'baglanti_tipi': 'Flansli (EN 1092-2)',
        'kv_degeri': '${[10, 16, 25, 40, 63, 100][random.nextInt(6)]} m3/h',
        'sizdirmazlik': 'Class IV',
        'karakteristik': 'Esit yuzdeli',
      };
    }
    if (cat == 'otomasyon') {
      final tork = [4, 5, 10, 15, 20, 30][random.nextInt(6)];
      return {
        'tork': '$tork Nm',
        'calisma_suresi': '${90 + random.nextInt(150)} sn',
        'yay_donus': random.nextBool() ? 'Var' : 'Yok',
        'besleme_gerilimi': '24 VAC/DC',
        'kontrol_sinyali': '0-10 V / 4-20 mA',
        'koruma_sinifi': 'IP54',
      };
    }
    // Elektrik / genel kategoriler icin sablon yok, bos birak.
    return const {};
  }

  Future<List<Product>> fetchProducts() async {
    if (_client == null) {
      return _sortedMemoryProducts();
    }

    final rows = await _client
        .from('products')
        .select()
        .order('updated_at', ascending: false);

    return rows
        .cast<Map<String, dynamic>>()
        .map(Product.fromJson)
        .toList(growable: false);
  }

  Future<void> saveProduct(Product product) async {
    _upsertMemoryProduct(product);

    if (_client == null) {
      return;
    }

    await _client.from('products').upsert(product.toJson());
  }

  Future<void> saveProducts(List<Product> products) async {
    for (final product in products) {
      _upsertMemoryProduct(product);
    }

    if (_client == null || products.isEmpty) {
      return;
    }

    await _client
        .from('products')
        .upsert(products.map((product) => product.toJson()).toList());
  }

  Future<int> applyPriceAdjustmentRule(PriceAdjustmentRule rule) async {
    final products = await fetchProducts();
    final updated = products
        .where(rule.matches)
        .map(
          (product) => product.copyWith(
            salePrice: _roundedPrice(
              product.salePrice * (1 + (rule.percentage / 100)),
            ),
            updatedAt: DateTime.now().toUtc(),
          ),
        )
        .toList(growable: false);

    for (final product in updated) {
      _upsertMemoryProduct(product);
    }

    if (_client != null && updated.isNotEmpty) {
      await _client
          .from('products')
          .upsert(updated.map((product) => product.toJson()).toList());
    }

    return updated.length;
  }

  List<Product> _sortedMemoryProducts() {
    final products = List<Product>.from(_memoryProducts);
    products.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return products;
  }

  void _upsertMemoryProduct(Product product) {
    final index = _memoryProducts.indexWhere((item) => item.id == product.id);
    if (index == -1) {
      _memoryProducts.add(product);
      return;
    }
    _memoryProducts[index] = product;
  }

  double _roundedPrice(double value) => double.parse(value.toStringAsFixed(2));
}
