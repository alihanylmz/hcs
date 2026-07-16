/// Urun kategorisine ozgu spesifikasyon sablonlari.
///
/// Her `SpecTemplate` bir veya birkac kategori ismi ile eslesir ve ilgili
/// UI icin hangi alanlarin nasil gruplanacagini tanimlar. Model icindeki
/// `Product.specifications` map'i bu sablonlardaki `key` degerleriyle
/// doldurulur; boylece veri modeli tek tip (String -> String) kalir ve UI
/// kategori bazinda dinamik olarak sekillenir.
class SpecField {
  const SpecField({
    required this.key,
    required this.label,
    this.hint = '',
    this.multiline = false,
  });

  /// Veritabaninda `specifications` jsonb'sinde anahtar olarak kullanilir.
  final String key;

  /// Kullaniciya gosterilen etiket.
  final String label;

  /// Input alaninda placeholder olarak gorunur ornegi.
  final String hint;

  /// Uzun metin (aciklama) alani ise true.
  final bool multiline;
}

class SpecGroup {
  const SpecGroup({required this.title, required this.fields});

  final String title;
  final List<SpecField> fields;
}

class SpecTemplate {
  const SpecTemplate({
    required this.label,
    required this.categoryMatches,
    required this.groups,
  });

  final String label;

  /// Kucuk harfe cevrilmis kategori adlari.
  final List<String> categoryMatches;
  final List<SpecGroup> groups;
}

class ProductSpecTemplates {
  ProductSpecTemplates._();

  static const inverter = SpecTemplate(
    label: 'Inverter',
    categoryMatches: [
      'inverter',
      'frekans surucu',
      'frekans sürücü',
      'ac surucu',
      'ac sürücü',
    ],
    groups: [
      SpecGroup(
        title: 'Genel Ozellikler',
        fields: [
          SpecField(
            key: 'besleme_gerilimi',
            label: 'Besleme Gerilimi',
            hint: '3x220VAC (Monofaze)',
          ),
          SpecField(
            key: 'besleme_frekansi',
            label: 'Besleme Frekansi',
            hint: '47 Hz ile 63 Hz arasi',
          ),
          SpecField(
            key: 'kontrol_modu',
            label: 'Kontrol Modu',
            hint: 'V/F ve sensorsuz vektor kontrolu (SVC)',
          ),
          SpecField(
            key: 'frekans_araligi',
            label: 'Frekans Araligi',
            hint: '0 Hz ile 599 Hz arasi',
          ),
          SpecField(
            key: 'ayir_cozunurlugu',
            label: 'Ayir Cozunurlugu',
            hint: 'Dijital: 0.01 Hz; Analog: Maksimum frekans / 2000',
          ),
          SpecField(
            key: 'asiri_yuk_akim_orani',
            label: 'Asiri Yuk Akim Orani',
            hint: '%150/60s, %180/10s',
          ),
          SpecField(
            key: 'hizlanma_yavaslama',
            label: 'Hizlanma / Yavaslama',
            hint: '0.1 sn ile 3600 sn arasi',
          ),
          SpecField(
            key: 'dc_frenleme',
            label: 'DC Frenleme',
            hint: 'Var / Yok',
          ),
          SpecField(
            key: 'pid_fonksiyonu',
            label: 'PID Fonksiyonu',
            hint: 'Var / Yok',
          ),
          SpecField(
            key: 'haberlesme',
            label: 'Haberlesme',
            hint: 'Standart MODBUS RTU, RS-485',
          ),
          SpecField(
            key: 'koruma_sinifi',
            label: 'Koruma Sinifi',
            hint: 'IP20, IP55',
          ),
        ],
      ),
      SpecGroup(
        title: 'Giris / Cikis',
        fields: [
          SpecField(
            key: 'dijital_giris',
            label: 'Dijital Giris',
            hint: '4 adet PNP veya NPN secilebilen dijital giris',
          ),
          SpecField(
            key: 'role_cikis',
            label: 'Role Cikis',
            hint: '2 adet programlanabilir role cikis',
          ),
          SpecField(
            key: 'hizli_puls_giris',
            label: 'Hizli Puls Giris',
            hint: '1 adet hizli puls giris',
          ),
          SpecField(
            key: 'analog_giris',
            label: 'Analog Giris',
            hint: '2 Kanal: 0/10V veya 0/20mA',
          ),
          SpecField(
            key: 'analog_cikis',
            label: 'Analog Cikis',
            hint: '1 adet programlanabilir 4-20 mA veya 0-10 V',
          ),
        ],
      ),
      SpecGroup(
        title: 'Guc / Akim Bilgileri',
        fields: [
          SpecField(
            key: 'guc',
            label: 'Guc',
            hint: 'Orn: 1.5 kW',
          ),
          SpecField(
            key: 'nominal_akim',
            label: 'Nominal Akim',
            hint: 'Orn: 7.5 A',
          ),
          SpecField(
            key: 'fren_direnci',
            label: 'Fren Direnci',
            hint: '95 - 1800 W',
          ),
        ],
      ),
    ],
  );

  static const controller = SpecTemplate(
    label: 'DDC Kontrolor',
    categoryMatches: [
      'ddc kontrolor',
      'ddc kontrolör',
      'kontrol',
      'kontrolor',
      'kontrolör',
      'otomasyon',
      'plc',
    ],
    groups: [
      SpecGroup(
        title: 'Genel Ozellikler',
        fields: [
          SpecField(
            key: 'besleme_gerilimi',
            label: 'Besleme Gerilimi',
            hint: '24 VAC / 24 VDC',
          ),
          SpecField(
            key: 'haberlesme_protokolu',
            label: 'Haberlesme Protokolu',
            hint: 'BACnet IP, Modbus TCP, RS-485',
          ),
          SpecField(
            key: 'programlama_dili',
            label: 'Programlama Dili',
            hint: 'IEC 61131-3, grafik editor',
          ),
          SpecField(
            key: 'cpu',
            label: 'CPU / Bellek',
            hint: 'ARM 32-bit, 8 MB flash',
          ),
          SpecField(
            key: 'web_arayuzu',
            label: 'Web Arayuzu',
            hint: 'Dahili HTML5 / Var / Yok',
          ),
          SpecField(
            key: 'gerçek_zaman_saati',
            label: 'Gercek Zaman Saati',
            hint: 'Pil destekli RTC',
          ),
        ],
      ),
      SpecGroup(
        title: 'Giris / Cikis Sayilari',
        fields: [
          SpecField(
            key: 'dijital_giris',
            label: 'Dijital Giris (DI)',
            hint: 'Orn: 8 kanal',
          ),
          SpecField(
            key: 'dijital_cikis',
            label: 'Dijital Cikis (DO)',
            hint: 'Orn: 4 kanal role',
          ),
          SpecField(
            key: 'analog_giris',
            label: 'Analog Giris (AI)',
            hint: '0-10V, 4-20mA, PT1000, NTC',
          ),
          SpecField(
            key: 'analog_cikis',
            label: 'Analog Cikis (AO)',
            hint: '0-10V, 4-20mA',
          ),
          SpecField(
            key: 'moduler_io',
            label: 'Moduler I/O Destegi',
            hint: 'Genisletme modulu ile X kanal',
          ),
        ],
      ),
      SpecGroup(
        title: 'Ortam Kosullari',
        fields: [
          SpecField(
            key: 'koruma_sinifi',
            label: 'Koruma Sinifi',
            hint: 'IP20 / IP54',
          ),
          SpecField(
            key: 'calisma_sicakligi',
            label: 'Calisma Sicakligi',
            hint: '0/+50 C',
          ),
          SpecField(
            key: 'montaj',
            label: 'Montaj Tipi',
            hint: 'DIN ray, panel',
          ),
        ],
      ),
    ],
  );

  static const sensor = SpecTemplate(
    label: 'Sensor',
    categoryMatches: [
      'sensor',
      'sensör',
      'sonda',
    ],
    groups: [
      SpecGroup(
        title: 'Olcum',
        fields: [
          SpecField(
            key: 'olculen_parametre',
            label: 'Olculen Parametre',
            hint: 'Sicaklik / Nem / Basinc / CO2',
          ),
          SpecField(
            key: 'sensor_tipi',
            label: 'Sensor Elemani',
            hint: 'PT1000, NTC, RTD, kapasitif',
          ),
          SpecField(
            key: 'olcum_araligi',
            label: 'Olcum Araligi',
            hint: '-50 / +80 C',
          ),
          SpecField(
            key: 'dogruluk',
            label: 'Dogruluk',
            hint: '+/- 0.5 C @ 25 C',
          ),
          SpecField(
            key: 'tepki_suresi',
            label: 'Tepki Suresi',
            hint: 'Orn: 10 sn',
          ),
        ],
      ),
      SpecGroup(
        title: 'Elektriksel',
        fields: [
          SpecField(
            key: 'cikis_sinyali',
            label: 'Cikis Sinyali',
            hint: '4-20 mA, 0-10 V, pasif (PT1000)',
          ),
          SpecField(
            key: 'besleme_gerilimi',
            label: 'Besleme Gerilimi',
            hint: '24 VAC/DC',
          ),
          SpecField(
            key: 'baglanti',
            label: 'Kablo / Baglanti',
            hint: '2 telli, 3 telli, konnektor',
          ),
        ],
      ),
      SpecGroup(
        title: 'Ortam Kosullari',
        fields: [
          SpecField(
            key: 'montaj_tipi',
            label: 'Montaj Tipi',
            hint: 'Kanal, duvar, daldirma, immersion',
          ),
          SpecField(
            key: 'koruma_sinifi',
            label: 'Koruma Sinifi',
            hint: 'IP54 / IP65',
          ),
          SpecField(
            key: 'calisma_sicakligi',
            label: 'Calisma Sicakligi',
            hint: 'Ornekleme sicakligi araligi',
          ),
          SpecField(
            key: 'prob_uzunlugu',
            label: 'Prob Uzunlugu',
            hint: 'Orn: 150 mm',
          ),
        ],
      ),
    ],
  );

  static const mechanical = SpecTemplate(
    label: 'Mekanik (Vana)',
    categoryMatches: ['mekanik', 'vana'],
    groups: [
      SpecGroup(
        title: 'Govde',
        fields: [
          SpecField(key: 'nominal_cap', label: 'Nominal Cap (DN)', hint: 'DN65'),
          SpecField(
            key: 'basinc_sinifi',
            label: 'Basinc Sinifi',
            hint: 'PN16 / PN25',
          ),
          SpecField(
            key: 'govde_malzemesi',
            label: 'Govde Malzemesi',
            hint: 'Sfero dokum, paslanmaz celik',
          ),
          SpecField(
            key: 'baglanti_tipi',
            label: 'Baglanti Tipi',
            hint: 'Flans, disli, kaynak',
          ),
        ],
      ),
      SpecGroup(
        title: 'Performans',
        fields: [
          SpecField(
            key: 'kv_degeri',
            label: 'Kv Degeri',
            hint: 'm3/h (Kvs)',
          ),
          SpecField(
            key: 'sizdirmazlik',
            label: 'Sizdirmazlik',
            hint: 'Class IV / EN 12266',
          ),
          SpecField(
            key: 'karakteristik',
            label: 'Akis Karakteristigi',
            hint: 'Esit yuzdeli, dogrusal',
          ),
        ],
      ),
    ],
  );

  static const actuator = SpecTemplate(
    label: 'Aktuator',
    categoryMatches: ['aktuator', 'aktüatör', 'damper aktuator'],
    groups: [
      SpecGroup(
        title: 'Mekanik',
        fields: [
          SpecField(key: 'tork', label: 'Tork', hint: '10 Nm'),
          SpecField(
            key: 'calisma_suresi',
            label: 'Calisma Suresi',
            hint: '150 sn',
          ),
          SpecField(
            key: 'yay_donus',
            label: 'Yay Donus',
            hint: 'Var / Yok',
          ),
        ],
      ),
      SpecGroup(
        title: 'Elektrik',
        fields: [
          SpecField(
            key: 'besleme_gerilimi',
            label: 'Besleme Gerilimi',
            hint: '24 VAC/DC',
          ),
          SpecField(
            key: 'kontrol_sinyali',
            label: 'Kontrol Sinyali',
            hint: '0-10 V, 2-10 V, 4-20 mA, floating',
          ),
          SpecField(
            key: 'koruma_sinifi',
            label: 'Koruma Sinifi',
            hint: 'IP54',
          ),
        ],
      ),
    ],
  );

  static const _all = <SpecTemplate>[
    inverter,
    controller,
    sensor,
    mechanical,
    actuator,
  ];

  /// Urun formu kategori acilir listesi; `label` degerleri `Product.category`
  /// alanina yazilir ve sablon eslemesi icin kullanilir.
  static List<String> get presetCategoryLabels => [
        'Genel',
        inverter.label,
        controller.label,
        sensor.label,
        mechanical.label,
        actuator.label,
      ];

  /// Verilen kategori adina uygun bir sablon dondurur. Hicbir sablonla
  /// eslesmezse null doner (UI generic bir "ek ozellikler yok" goruntulemesi
  /// yapabilir).
  static SpecTemplate? findForCategory(String category) {
    final lower = category.trim().toLowerCase();
    if (lower.isEmpty) return null;
    for (final template in _all) {
      for (final candidate in template.categoryMatches) {
        if (lower == candidate || lower.contains(candidate)) {
          return template;
        }
      }
    }
    return null;
  }
}
