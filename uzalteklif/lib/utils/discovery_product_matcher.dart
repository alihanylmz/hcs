import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
      mainCategory: 'Sensörler',
      subcategories: {},
      reason: 'Dijital veya genel nokta için sensör ve presostat öneriliyor.',
    ),
  };
}

/// Kullanicinin bizzat yildizlayarak (⭐) varsayilan yaptigi urunlerin kategorisel hafizasi
final Map<String, String> _userFavoriteProductIds = {};
bool _isFavLoaded = false;

String _getCurrentUserPrefix() {
  final email = Supabase.instance.client.auth.currentUser?.email?.trim().toLowerCase() ?? '';
  if (email.isNotEmpty) return email.replaceAll(RegExp(r'[^a-z0-9]'), '_');
  final uid = Supabase.instance.client.auth.currentUser?.id ?? 'default';
  return uid;
}

Future<void> loadUserFavoriteProducts() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _getCurrentUserPrefix();
    final keys = prefs.getKeys().where((k) => k.startsWith('fav_prod_${prefix}_'));
    for (final key in keys) {
      final catKey = key.replaceFirst('fav_prod_${prefix}_', '');
      final val = prefs.getString(key);
      if (val != null && val.isNotEmpty) {
        _userFavoriteProductIds[catKey] = val;
      }
    }
    _isFavLoaded = true;
  } catch (_) {}
}

void setUserFavoriteProduct(String categoryKey, String productId) async {
  if (productId.isEmpty) {
    _userFavoriteProductIds.remove(categoryKey);
  } else {
    _userFavoriteProductIds[categoryKey] = productId;
  }

  try {
    final prefs = await SharedPreferences.getInstance();
    final prefix = _getCurrentUserPrefix();
    final prefKey = 'fav_prod_${prefix}_$categoryKey';
    if (productId.isEmpty) {
      await prefs.remove(prefKey);
    } else {
      await prefs.setString(prefKey, productId);
    }
  } catch (_) {}
}

String? getUserFavoriteProductId(String categoryKey) {
  if (!_isFavLoaded) {
    loadUserFavoriteProducts();
  }
  return _userFavoriteProductIds[categoryKey];
}

String getCategoryKeyForPoint(DiscoveryPoint point) {
  final name = point.name.toLowerCase();
  if (name.contains('sicaklik') || name.contains('sıcaklık')) return 'sicaklik_sensoru';
  if (name.contains('damper')) return 'damper_aktuatoru';
  if (name.contains('vana')) return 'vana_aktuatoru';
  if (name.contains('basinc') || name.contains('basınç')) return 'basinc_sensoru';
  if (name.contains('nem')) return 'nem_sensoru';
  return point.type.name;
}

/// Nokta turune veya adina gore stok katalogundan en uygun varsayilan urunu otomatik secer.
/// Kullanici bir urunu ⭐ ile varsayilan yapmissa, tum ayni tur noktalar otomatik o urunle acilir!
Product? findDefaultProductForPoint(DiscoveryPoint point, List<Product> products) {
  if (products.isEmpty) return null;
  
  // 0. Kullanicinin bizzat ⭐ yildizladigi varsayilan urun var mi kontrol et
  final catKey = getCategoryKeyForPoint(point);
  final favId = _userFavoriteProductIds[catKey];
  if (favId != null && favId.isNotEmpty) {
    for (final p in products) {
      if (p.id == favId && p.isActive) return p;
    }
  }

  final rec = recommendationForDiscoveryPoint(point);

  // 1. Once kategori ve alt kategoriye tam uyan ilk aktif stoklu urunu ara
  final exactMatches = products.where((p) => p.isActive && rec.matches(p)).toList();
  if (exactMatches.isNotEmpty) {
    // Stokta var olan urunleri onceliklendir
    final inStock = exactMatches.where((p) => p.stockQuantity > 0).toList();
    return inStock.isNotEmpty ? inStock.first : exactMatches.first;
  }

  // 2. Nokta turune gore genel kategori aramasi yap
  final categoryMatches = products.where((p) {
    if (!p.isActive) return false;
    final main = productMainCategoryTurkishLabel(p).toLowerCase();
    if (point.name.toLowerCase().contains('sicaklik') || point.name.toLowerCase().contains('sıcaklık')) {
      return p.name.toLowerCase().contains('sıcaklık') || p.name.toLowerCase().contains('sicaklik') || p.name.toLowerCase().contains('sensor');
    }
    if (point.name.toLowerCase().contains('damper') || point.name.toLowerCase().contains('vana')) {
      return main.contains('aktüatör') || main.contains('vana');
    }
    return rec.mainCategory.isNotEmpty && main.contains(rec.mainCategory.toLowerCase());
  }).toList();

  if (categoryMatches.isNotEmpty) {
    return categoryMatches.first;
  }

  return null;
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
