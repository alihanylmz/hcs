import 'product.dart';

enum PriceAdjustmentScope {
  brand,
  category,
  brandAndCategory,
}

extension PriceAdjustmentScopeX on PriceAdjustmentScope {
  String get storageKey {
    switch (this) {
      case PriceAdjustmentScope.brand:
        return 'brand';
      case PriceAdjustmentScope.category:
        return 'category';
      case PriceAdjustmentScope.brandAndCategory:
        return 'brand_category';
    }
  }

  String get label {
    switch (this) {
      case PriceAdjustmentScope.brand:
        return 'Marka';
      case PriceAdjustmentScope.category:
        return 'Kategori';
      case PriceAdjustmentScope.brandAndCategory:
        return 'Marka + Kategori';
    }
  }

  static PriceAdjustmentScope fromStorageKey(String? raw) {
    switch (raw) {
      case 'category':
        return PriceAdjustmentScope.category;
      case 'brand_category':
        return PriceAdjustmentScope.brandAndCategory;
      default:
        return PriceAdjustmentScope.brand;
    }
  }
}

class PriceAdjustmentRule {
  const PriceAdjustmentRule({
    required this.id,
    required this.name,
    required this.scope,
    required this.percentage,
    required this.isActive,
    required this.updatedAt,
    this.brand = '',
    this.category = '',
  });

  final String id;
  final String name;
  final PriceAdjustmentScope scope;
  final String brand;
  final String category;
  final double percentage;
  final bool isActive;
  final DateTime updatedAt;

  bool matches(Product product) {
    if (!isActive) return false;
    final productBrand = _normalize(product.brand);
    final productCategory = _normalize(product.category);
    final ruleBrand = _normalize(brand);
    final ruleCategory = _normalize(category);

    switch (scope) {
      case PriceAdjustmentScope.brand:
        return ruleBrand.isNotEmpty && productBrand == ruleBrand;
      case PriceAdjustmentScope.category:
        return ruleCategory.isNotEmpty && productCategory == ruleCategory;
      case PriceAdjustmentScope.brandAndCategory:
        return ruleBrand.isNotEmpty &&
            ruleCategory.isNotEmpty &&
            productBrand == ruleBrand &&
            productCategory == ruleCategory;
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'scope': scope.storageKey,
        'brand': brand,
        'category': category,
        'percentage': percentage,
        'is_active': isActive,
        'updated_at': updatedAt.toIso8601String(),
      };

  factory PriceAdjustmentRule.fromJson(Map<String, dynamic> json) {
    return PriceAdjustmentRule(
      id: json['id'] as String? ?? '',
      name: (json['name'] as String?)?.trim() ?? '',
      scope: PriceAdjustmentScopeX.fromStorageKey(json['scope'] as String?),
      brand: (json['brand'] as String?)?.trim() ?? '',
      category: (json['category'] as String?)?.trim() ?? '',
      percentage: (json['percentage'] as num?)?.toDouble() ?? 0,
      isActive: json['is_active'] as bool? ?? true,
      updatedAt: DateTime.parse(
        json['updated_at'] as String? ?? DateTime.now().toIso8601String(),
      ),
    );
  }

  static String _normalize(String raw) => raw.trim().toLowerCase();
}

class PriceAdjustmentResult {
  const PriceAdjustmentResult({
    required this.basePriceTl,
    required this.adjustedPriceTl,
    required this.totalPercentage,
    required this.rules,
  });

  final double basePriceTl;
  final double adjustedPriceTl;
  final double totalPercentage;
  final List<PriceAdjustmentRule> rules;

  bool get hasAdjustment => rules.isNotEmpty && totalPercentage != 0;
}

PriceAdjustmentResult applyPriceAdjustmentRules({
  required Product product,
  required Map<String, double> rates,
  required List<PriceAdjustmentRule> rules,
}) {
  final base = product.priceInTl(rates);
  final matched = rules.where((rule) => rule.matches(product)).toList();
  final totalPercent =
      matched.fold<double>(0, (sum, rule) => sum + rule.percentage);
  final adjusted = base * (1 + (totalPercent / 100));
  return PriceAdjustmentResult(
    basePriceTl: base,
    adjustedPriceTl: adjusted < 0 ? 0 : adjusted,
    totalPercentage: totalPercent,
    rules: matched,
  );
}
