import 'package:intl/intl.dart';

class Product {
  const Product({
    required this.id,
    required this.code,
    required this.name,
    required this.category,
    required this.brand,
    required this.model,
    required this.unit,
    required this.currencyCode,
    required this.salePrice,
    required this.stockQuantity,
    required this.minimumStock,
    required this.vatRate,
    required this.leadTime,
    required this.description,
    required this.technicalSummary,
    required this.isActive,
    required this.updatedAt,
    this.imagePath = '',
    this.specifications = const {},
  });

  final String id;
  final String code;
  final String name;
  final String category;
  final String brand;
  final String model;
  final String unit;
  final String currencyCode;
  final double salePrice;
  final double stockQuantity;
  final double minimumStock;
  final double vatRate;
  final String leadTime;
  final String description;
  final String technicalSummary;
  final bool isActive;
  final DateTime updatedAt;

  /// Uruna ait tam nitelikli dosya yolu (PNG/JPG). Bos ise urunun resmi yok.
  /// Resim yerel uygulama veri dizinine kopyalandigi icin yol mutlak olarak
  /// tutulur; ayni bilgisayarda calisan kurulumlar icin anlamlidir.
  final String imagePath;

  /// Kategoriye ozgu teknik spesifikasyonlar. Anahtar `ProductSpecTemplates`
  /// icindeki `SpecField.key` ile eslesir; deger kullanicinin yazdigi serbest
  /// metindir. Bu alan, UI'da "Spesifikasyonlar" bolumu olarak kategoriye
  /// gore gruplanmis sekilde gosterilir. JSONB olarak Supabase'e yazilir.
  final Map<String, String> specifications;

  /// Sadece `imagePath` degerini degistirerek yeni bir kopya doner. Dugun
  /// saatinde tum Product alanlarini tekrar yazmadan resim guncelleme
  /// akislari bunu kullanir.
  Product copyWithImage(String newPath) {
    return copyWith(imagePath: newPath, updatedAt: DateTime.now());
  }

  Product copyWith({
    String? id,
    String? code,
    String? name,
    String? category,
    String? brand,
    String? model,
    String? unit,
    String? currencyCode,
    double? salePrice,
    double? stockQuantity,
    double? minimumStock,
    double? vatRate,
    String? leadTime,
    String? description,
    String? technicalSummary,
    bool? isActive,
    DateTime? updatedAt,
    String? imagePath,
    Map<String, String>? specifications,
  }) {
    return Product(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      category: category ?? this.category,
      brand: brand ?? this.brand,
      model: model ?? this.model,
      unit: unit ?? this.unit,
      currencyCode: currencyCode ?? this.currencyCode,
      salePrice: salePrice ?? this.salePrice,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      minimumStock: minimumStock ?? this.minimumStock,
      vatRate: vatRate ?? this.vatRate,
      leadTime: leadTime ?? this.leadTime,
      description: description ?? this.description,
      technicalSummary: technicalSummary ?? this.technicalSummary,
      isActive: isActive ?? this.isActive,
      updatedAt: updatedAt ?? this.updatedAt,
      imagePath: imagePath ?? this.imagePath,
      specifications: specifications ?? this.specifications,
    );
  }

  bool get isLowStock => stockQuantity <= minimumStock;

  String get currencyLabel => switch (currencyCode) {
        'USDTRY' => 'USD',
        'EURTRY' => 'EUR',
        _ => 'TL',
      };

  String get formattedSalePrice {
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: switch (currencyCode) {
        'USDTRY' => r'$ ',
        'EURTRY' => 'EUR ',
        _ => 'TL ',
      },
      decimalDigits: 2,
    );
    return formatter.format(salePrice);
  }

  String get formattedStock =>
      '${stockQuantity.toStringAsFixed(stockQuantity.truncateToDouble() == stockQuantity ? 0 : 1)} $unit';

  String get formattedVat => '%${vatRate.toStringAsFixed(0)}';

  double priceInTl(Map<String, double> rates) {
    if (currencyCode == 'TL') {
      return salePrice;
    }

    final rate = rates[currencyCode];
    if (rate == null || rate == 0) {
      return salePrice;
    }

    return salePrice * rate;
  }

  String formattedTlEquivalent(Map<String, double> rates) {
    final formatter = NumberFormat.currency(
      locale: 'tr_TR',
      symbol: 'TL ',
      decimalDigits: 2,
    );
    return formatter.format(priceInTl(rates));
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'category': category,
        'brand': brand,
        'model': model,
        'unit': unit,
        'currency_code': currencyCode,
        'sale_price': salePrice,
        'stock_quantity': stockQuantity,
        'minimum_stock': minimumStock,
        'vat_rate': vatRate,
        'lead_time': leadTime,
        'description': description,
        'technical_summary': technicalSummary,
        'is_active': isActive,
        'updated_at': updatedAt.toIso8601String(),
        'image_path': imagePath,
        'specifications': specifications,
      };

  factory Product.fromJson(Map<String, dynamic> json) {
    return Product(
      id: json['id'] as String? ?? '',
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      category: json['category'] as String? ?? '',
      brand: json['brand'] as String? ?? '',
      model: json['model'] as String? ?? '',
      unit: json['unit'] as String? ?? 'adet',
      currencyCode: json['currency_code'] as String? ?? 'TL',
      salePrice: (json['sale_price'] as num?)?.toDouble() ?? 0,
      stockQuantity: (json['stock_quantity'] as num?)?.toDouble() ?? 0,
      minimumStock: (json['minimum_stock'] as num?)?.toDouble() ?? 0,
      vatRate: (json['vat_rate'] as num?)?.toDouble() ?? 20,
      leadTime: json['lead_time'] as String? ?? '',
      description: json['description'] as String? ?? '',
      technicalSummary: json['technical_summary'] as String? ?? '',
      isActive: json['is_active'] as bool? ?? true,
      updatedAt: DateTime.parse(
        json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
      imagePath: (json['image_path'] as String?)?.trim() ?? '',
      specifications: _readSpecifications(json['specifications']),
    );
  }

  static Map<String, String> _readSpecifications(dynamic raw) {
    if (raw is Map) {
      final result = <String, String>{};
      raw.forEach((key, value) {
        if (key is String && value != null) {
          final stringValue = value.toString().trim();
          if (stringValue.isNotEmpty) {
            result[key] = stringValue;
          }
        }
      });
      return result;
    }
    return const {};
  }
}
