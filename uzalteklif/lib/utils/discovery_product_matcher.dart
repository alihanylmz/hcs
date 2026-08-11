import '../models/discovery_project.dart';
import '../models/product.dart';
import 'product_category_labels.dart';

class DiscoveryProductRecommendation {
  const DiscoveryProductRecommendation({
    required this.mainCategory,
    required this.subcategories,
    required this.reason,
  });

  final String mainCategory;
  final Set<String> subcategories;
  final String reason;

  bool matches(Product product) {
    final main = _normalize(productMainCategoryTurkishLabel(product));
    if (main != _normalize(mainCategory)) return false;
    if (subcategories.isEmpty) return true;
    final sub = _normalize(productSubcategoryTurkishLabel(product));
    return subcategories.map(_normalize).contains(sub);
  }
}

DiscoveryProductRecommendation recommendationForDiscoveryPoint(
  DiscoveryPoint point,
) {
  final name = _normalize(point.name);
  if (_containsAny(name, const ['sicaklik', 'temperature', 'ntc', 'pt100'])) {
    return const DiscoveryProductRecommendation(
      mainCategory: 'Sensörler',
      subcategories: {'Sıcaklık Sensörleri'},
      reason: 'Nokta adı sıcaklık ölçümü içeriyor.',
    );
  }
  if (_containsAny(name, const ['fark basinc', 'differential pressure'])) {
    return const DiscoveryProductRecommendation(
      mainCategory: 'Sensörler',
      subcategories: {'Fark Basınç Sensörleri', 'Basınç Sensörleri'},
      reason: 'Nokta adı fark basınç ölçümü içeriyor.',
    );
  }
  if (_containsAny(name, const ['basinc', 'pressure', 'filtre kirlilik'])) {
    return const DiscoveryProductRecommendation(
      mainCategory: 'Sensörler',
      subcategories: {'Basınç Sensörleri', 'Fark Basınç Sensörleri'},
      reason: 'Nokta basınç veya filtre kirlilik ölçümü içeriyor.',
    );
  }
  if (_containsAny(name, const ['nem', 'humidity'])) {
    return const DiscoveryProductRecommendation(
      mainCategory: 'Sensörler',
      subcategories: {'Nem Sensörleri'},
      reason: 'Nokta adı nem ölçümü içeriyor.',
    );
  }
  if (_containsAny(name, const ['co2', 'hava kalite', 'air quality'])) {
    return const DiscoveryProductRecommendation(
      mainCategory: 'Sensörler',
      subcategories: {'Hava Kalitesi Sensörleri'},
      reason: 'Nokta hava kalitesi ölçümü içeriyor.',
    );
  }
  if (_containsAny(name, const ['debi', 'flow'])) {
    return const DiscoveryProductRecommendation(
      mainCategory: 'Sensörler',
      subcategories: {'Debi Sensörleri'},
      reason: 'Nokta adı debi ölçümü içeriyor.',
    );
  }
  if (_containsAny(name, const [
    'inverter',
    'inv',
    'frekans',
    'surucu',
    'sürücü',
    'hiz kontrol',
    'hız kontrol',
    'speed control',
    'fan hiz',
    'fan hız',
    'pompa hiz',
    'pompa hız',
  ])) {
    return const DiscoveryProductRecommendation(
      mainCategory: 'HVAC ve Sürücüler',
      subcategories: {},
      reason: 'Nokta adı frekans sürücü veya inverter ihtiyacı içeriyor.',
    );
  }
  if (_containsAny(name, const ['damper motor'])) {
    return const DiscoveryProductRecommendation(
      mainCategory: 'Aktüatör ve Vanalar',
      subcategories: {'Damper Aktüatörleri'},
      reason: 'Nokta damper motoru kumandası içeriyor.',
    );
  }
  if (_containsAny(name, const ['vana motor', 'valve actuator'])) {
    return const DiscoveryProductRecommendation(
      mainCategory: 'Aktüatör ve Vanalar',
      subcategories: {'Vana Aktüatörleri'},
      reason: 'Nokta vana motoru kumandası içeriyor.',
    );
  }
  return switch (point.type) {
    DiscoveryPointType.aiActive ||
    DiscoveryPointType.aiPassive => const DiscoveryProductRecommendation(
      mainCategory: 'Sensörler',
      subcategories: {},
      reason: 'Analog giriş noktası için sensörler öneriliyor.',
    ),
    DiscoveryPointType.ao ||
    DiscoveryPointType.doOutput => const DiscoveryProductRecommendation(
      mainCategory: 'Aktüatör ve Vanalar',
      subcategories: {},
      reason: 'Çıkış noktası için saha ekipmanları öneriliyor.',
    ),
    _ => const DiscoveryProductRecommendation(
      mainCategory: '',
      subcategories: {},
      reason: 'Bu nokta için kesin bir ürün kategorisi belirlenemedi.',
    ),
  };
}

bool _containsAny(String source, List<String> values) =>
    values.any((value) => source.contains(value));

String _normalize(String value) {
  return value
      .trim()
      .toLowerCase()
      .replaceAll('ı', 'i')
      .replaceAll('ş', 's')
      .replaceAll('ğ', 'g')
      .replaceAll('ü', 'u')
      .replaceAll('ö', 'o')
      .replaceAll('ç', 'c')
      .replaceAll(RegExp(r'\s+'), ' ');
}
