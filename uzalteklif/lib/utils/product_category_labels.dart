import '../models/product.dart';

const productCatalogMainCategoryKey = 'catalog_main_category';
const productCatalogSubcategoryKey = 'catalog_subcategory';

enum ProductMainCategory {
  controller,
  ioModule,
  hmi,
  sensor,
  actuatorValve,
  thermostat,
  hvacDrive,
  metering,
  networkCommunication,
  softwarePlatform,
  accessory,
  other,
}

extension ProductMainCategoryX on ProductMainCategory {
  String get label => switch (this) {
    ProductMainCategory.controller => 'Kontrolörler',
    ProductMainCategory.ioModule => 'I/O Modülleri',
    ProductMainCategory.hmi => 'HMI / Operatör Panelleri',
    ProductMainCategory.sensor => 'Sensörler',
    ProductMainCategory.actuatorValve => 'Aktüatör ve Vanalar',
    ProductMainCategory.thermostat => 'Termostatlar',
    ProductMainCategory.hvacDrive => 'HVAC ve Sürücüler',
    ProductMainCategory.metering => 'Sayaç ve Ölçüm',
    ProductMainCategory.networkCommunication => 'Ağ ve Haberleşme',
    ProductMainCategory.softwarePlatform => 'Yazılım ve Platformlar',
    ProductMainCategory.accessory => 'Aksesuarlar',
    ProductMainCategory.other => 'Diğer',
  };
}

String productMainCategoryTurkishLabel(Product product) {
  final explicit =
      product.specifications[productCatalogMainCategoryKey]?.trim() ?? '';
  return explicit.isEmpty ? productMainCategoryFor(product).label : explicit;
}

ProductMainCategory productMainCategoryFor(Product product) {
  final explicit =
      product.specifications[productCatalogMainCategoryKey]?.trim() ?? '';
  if (explicit.isNotEmpty) {
    final normalized = _normalizeCatalogText(explicit);
    for (final category in ProductMainCategory.values) {
      if (_normalizeCatalogText(category.label) == normalized) return category;
    }
    if (normalized.contains('kontrolor')) {
      return ProductMainCategory.controller;
    }
    if (normalized.contains('i/o') || normalized.contains('io modul')) {
      return ProductMainCategory.ioModule;
    }
    if (normalized.contains('sensor')) return ProductMainCategory.sensor;
    if (normalized.contains('hmi')) return ProductMainCategory.hmi;
    if (normalized.contains('vana') || normalized.contains('aktuator')) {
      return ProductMainCategory.actuatorValve;
    }
  }
  final category = _normalizeCatalogText(product.category);
  final searchable = _productSearchableText(product);
  if (category.contains('controller accessor') ||
      category.contains('controller service part')) {
    return ProductMainCategory.accessory;
  }
  if (category.contains('remote temperature controller')) {
    return ProductMainCategory.thermostat;
  }
  if (searchable.contains('accessor')) return ProductMainCategory.accessory;
  if (searchable.contains('hmi') ||
      searchable.contains('operator panel') ||
      searchable.contains('operatör panel')) {
    return ProductMainCategory.hmi;
  }
  if (_hasPhysicalIoEvidence(searchable)) return ProductMainCategory.ioModule;
  if (_hasPhysicalControllerEvidence(searchable)) {
    return ProductMainCategory.controller;
  }
  if (searchable.contains('software') ||
      searchable.contains('cloud') ||
      searchable.contains('niagara') ||
      searchable.contains('platform') ||
      searchable.contains('core brand app') ||
      searchable.contains('connected homes')) {
    return ProductMainCategory.softwarePlatform;
  }
  if (searchable.contains('meter') ||
      searchable.contains('submeter') ||
      searchable.contains('ölçüm') ||
      searchable.contains('olcum')) {
    return ProductMainCategory.metering;
  }
  if (searchable.contains('industrial switch') ||
      searchable.contains('network') ||
      searchable.contains('haberleşme') ||
      searchable.contains('haberlesme')) {
    return ProductMainCategory.networkCommunication;
  }
  if (searchable.contains('dedicated io') ||
      searchable.contains('i/o mod') ||
      searchable.contains('io mod') ||
      searchable.contains('communication module')) {
    return ProductMainCategory.ioModule;
  }
  if (searchable.contains('controller') ||
      searchable.contains('kontrolor') ||
      searchable.contains('fbxi') ||
      searchable.contains('unitary 16')) {
    return ProductMainCategory.controller;
  }
  if (searchable.contains('thermostat') || searchable.contains('termostat')) {
    return ProductMainCategory.thermostat;
  }
  if (searchable.contains('sensor') ||
      searchable.contains('sensör') ||
      searchable.contains('pressure') ||
      searchable.contains('basınç')) {
    return ProductMainCategory.sensor;
  }
  if (searchable.contains('actuator') ||
      searchable.contains('aktüatör') ||
      searchable.contains('aktuator') ||
      searchable.contains('valve') ||
      searchable.contains('vana')) {
    return ProductMainCategory.actuatorValve;
  }
  if (searchable.contains('air treatment') ||
      searchable.contains('inverter') ||
      searchable.contains('cls-air') ||
      searchable.contains('hvac')) {
    return ProductMainCategory.hvacDrive;
  }
  return ProductMainCategory.other;
}

bool productMatchesHardwareCategory(
  Product product,
  ProductMainCategory target,
) {
  assert(
    target == ProductMainCategory.controller ||
        target == ProductMainCategory.ioModule,
  );
  final explicit =
      product.specifications[productCatalogMainCategoryKey]?.trim() ?? '';
  if (explicit.isNotEmpty) {
    return productMainCategoryFor(product) == target;
  }

  final category = _normalizeCatalogText(product.category);
  final searchable = _productSearchableText(product);
  if (_isControlHardwareAccessoryOrServicePart(category, searchable)) {
    return false;
  }

  if (target == ProductMainCategory.controller) {
    if (_hasPhysicalControllerEvidence(searchable)) return true;
    const controllerCategories = <String>{
      'ddc controller',
      'ddc kontrolor',
      'kontrolorler',
      'unitary controllers',
      'vav controllers',
      'zone controllers',
    };
    return controllerCategories.contains(category);
  }

  if (_isNonHardwareIoRecord(searchable)) return false;
  if (category == 'dedicated io' ||
      category == 'i/o modulleri' ||
      category == 'io modulleri') {
    return true;
  }
  return _hasPhysicalIoEvidence(searchable);
}

String productSubcategoryTurkishLabel(Product product) {
  final explicit =
      product.specifications[productCatalogSubcategoryKey]?.trim() ?? '';
  if (explicit.isNotEmpty) return explicit;
  final searchable = [
    product.category,
    product.name,
    product.description,
  ].join(' ').toLowerCase();
  switch (productMainCategoryFor(product)) {
    case ProductMainCategory.sensor:
      if (searchable.contains('differential pressure') ||
          searchable.contains('fark basınç') ||
          searchable.contains('fark basinc')) {
        return 'Fark Basınç Sensörleri';
      }
      if (searchable.contains('temperature') ||
          searchable.contains('sıcaklık') ||
          searchable.contains('sicaklik') ||
          searchable.contains('ntc') ||
          searchable.contains('pt100')) {
        return 'Sıcaklık Sensörleri';
      }
      if (searchable.contains('humidity') || searchable.contains('nem')) {
        return 'Nem Sensörleri';
      }
      if (searchable.contains('co2') ||
          searchable.contains('air quality') ||
          searchable.contains('hava kalite')) {
        return 'Hava Kalitesi Sensörleri';
      }
      if (searchable.contains('flow') || searchable.contains('debi')) {
        return 'Debi Sensörleri';
      }
      if (searchable.contains('pressure') ||
          searchable.contains('basınç') ||
          searchable.contains('basinc')) {
        return 'Basınç Sensörleri';
      }
      return productCategoryTurkishLabel(product.category);
    case ProductMainCategory.actuatorValve:
      if (searchable.contains('damper')) return 'Damper Aktüatörleri';
      if (searchable.contains('valve actuator') ||
          searchable.contains('vana akt')) {
        return 'Vana Aktüatörleri';
      }
      if (searchable.contains('valve') || searchable.contains('vana')) {
        return 'Kontrol Vanaları';
      }
      return productCategoryTurkishLabel(product.category);
    case ProductMainCategory.ioModule:
      if (searchable.contains('remote')) return 'Remote I/O Modülleri';
      if (searchable.contains('communication') ||
          searchable.contains('haberleşme') ||
          searchable.contains('haberlesme')) {
        return 'Haberleşme Modülleri';
      }
      return productCategoryTurkishLabel(product.category);
    case ProductMainCategory.hmi:
      if (searchable.contains('local')) return 'Yerel HMI';
      if (searchable.contains('system wide')) return 'Sistem Geneli HMI';
      return productCategoryTurkishLabel(product.category);
    default:
      return productCategoryTurkishLabel(product.category);
  }
}

Product withProductCatalogClassification(
  Product product, {
  required String mainCategory,
  required String subcategory,
}) {
  final specifications = Map<String, String>.from(product.specifications);
  final normalizedMain = mainCategory.trim();
  final normalizedSub = subcategory.trim();
  if (normalizedMain.isEmpty) {
    specifications.remove(productCatalogMainCategoryKey);
  } else {
    specifications[productCatalogMainCategoryKey] = normalizedMain;
  }
  if (normalizedSub.isEmpty) {
    specifications.remove(productCatalogSubcategoryKey);
  } else {
    specifications[productCatalogSubcategoryKey] = normalizedSub;
  }
  return product.copyWith(
    specifications: specifications,
    updatedAt: DateTime.now().toUtc(),
  );
}

String _normalizeCatalogText(String value) {
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

String _productSearchableText(Product product) {
  return _normalizeCatalogText(
    [
      product.code,
      product.name,
      product.category,
      product.brand,
      product.model,
      product.description,
      product.technicalSummary,
    ].join(' '),
  );
}

bool _isControlHardwareAccessoryOrServicePart(
  String category,
  String searchable,
) {
  return category.contains('controller accessor') ||
      category.contains('controller service part') ||
      searchable.contains('terminal block') ||
      searchable.contains('terminal cover') ||
      searchable.contains('rail clip') ||
      searchable.contains('antenna kit') ||
      searchable.contains('protective end cover') ||
      searchable.contains('relay output jumper');
}

bool _isNonHardwareControllerRecord(String searchable) {
  final isControllerWithoutLicense =
      searchable.contains('w/o license') ||
      searchable.contains('without license');
  return (!isControllerWithoutLicense &&
          (searchable.contains('license') || searchable.contains('licence'))) ||
      searchable.contains(' lisans ') ||
      searchable.contains(' basic lic ') ||
      searchable.contains(' baslic ') ||
      searchable.contains('upgrade') ||
      searchable.contains('software update') ||
      searchable.contains(' s/w update ') ||
      searchable.contains(' sma ') ||
      searchable.contains('demo license') ||
      searchable.contains('globpts') ||
      searchable.contains('pbpts') ||
      RegExp(r'\badd \d+ dev\b').hasMatch(searchable);
}

bool _isNonHardwareIoRecord(String searchable) {
  return searchable.contains('adaptor') ||
      searchable.contains('adapter') ||
      searchable.contains('jumper') ||
      searchable.contains('terminal') ||
      searchable.contains('accessor') ||
      searchable.contains('service part');
}

bool _hasPhysicalControllerEvidence(String searchable) {
  if (_isNonHardwareControllerRecord(searchable)) return false;
  return searchable.contains('plant controller') ||
      searchable.contains('unitary controller') ||
      searchable.contains('vav controller') ||
      searchable.contains('zone controller') ||
      searchable.contains('ddc controller') ||
      searchable.contains('ddc kontrolor') ||
      searchable.contains('bacnet ms/tp hvac controller') ||
      searchable.contains('bacnet mstp hvac controller') ||
      searchable.contains('hvac controller') ||
      searchable.contains('programmable controller') ||
      searchable.contains('supervisory controller') ||
      searchable.contains('fbxi') ||
      searchable.contains('unitary 16') ||
      searchable.contains('hawk8') ||
      searchable.contains('n-adv device') ||
      RegExp(r'\bclmers\d').hasMatch(searchable);
}

bool _hasPhysicalIoEvidence(String searchable) {
  if (_isNonHardwareIoRecord(searchable)) return false;
  return searchable.contains('i/o module') ||
      searchable.contains('io module') ||
      searchable.contains('mixed i/o') ||
      searchable.contains('mixed io') ||
      searchable.contains('panel i/o') ||
      searchable.contains('panel io') ||
      searchable.contains('remote i/o') ||
      searchable.contains('remote io') ||
      RegExp(r'\b\d+\s*(ai|ao|di|do|ui|uio)\b').hasMatch(searchable) ||
      RegExp(r'\bclio[pn]?\d').hasMatch(searchable);
}

String productCategoryTurkishLabel(String raw) {
  final category = raw.trim();
  final key = category.toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  const labels = <String, String>{
    '': 'Kategorisiz',
    'genel': 'Genel',
    'accessories': 'Aksesuarlar',
    'actuators': 'Aktüatörler',
    'air treatment': 'Hava Şartlandırma',
    'airflow control valves': 'Hava Akış Kontrol Vanaları',
    'btu and flow meters': 'BTU ve Debi Sayaçları',
    'connected homes': 'Bağlantılı Ev Sistemleri',
    'control valves & actuators': 'Kontrol Vanaları ve Aktüatörler',
    'controller accessories': 'Kontrolör Aksesuarları',
    'controller service parts': 'Kontrolör Servis Parçaları',
    'core brand app': 'Temel Marka Uygulamaları',
    'dedicated io': 'Özel I/O Modülleri',
    'digital airflow control valves': 'Dijital Hava Akış Kontrol Vanaları',
    'discrete communication modules': 'Ayrık Haberleşme Modülleri',
    'ddc kontrolor': 'DDC Kontrolörleri',
    'ddc kontrolör': 'DDC Kontrolörleri',
    'ebi core platform': 'EBI Ana Platformu',
    'hmi': 'HMI / Operatör Panelleri',
    'hmis': 'HMI / Operatör Panelleri',
    'industrial switches': 'Endüstriyel Ağ Anahtarları',
    'inverter': 'İnvertörler',
    'legacy products': 'Eski Nesil Ürünler',
    'lighting control': 'Aydınlatma Kontrolü',
    'local hmi': 'Yerel HMI',
    'plant controllers w/ onboard io': 'Dahili I/O’lu Tesis Kontrolörleri',
    'plant controllers w/o onboard io': 'Dahili I/O’suz Tesis Kontrolörleri',
    'pressure': 'Basınç',
    'raw materials and shared components': 'Hammaddeler ve Ortak Bileşenler',
    'remote temperature controllers': 'Uzak Sıcaklık Kontrolörleri',
    'sensor': 'Sensörler',
    'sensors and wall modules': 'Sensörler ve Duvar Modülleri',
    'software maintenance agreement': 'Yazılım Bakım Sözleşmesi',
    'submetering': 'Alt Ölçüm',
    'supervisor cloud': 'Bulut Üst Yönetim',
    'system wide hmi': 'Sistem Geneli HMI',
    'thermostats': 'Termostatlar',
    'unitary controllers': 'Paket Cihaz Kontrolörleri',
    'vav controllers': 'VAV Kontrolörleri',
    'valve & actuator assemblies': 'Vana ve Aktüatör Grupları',
    'valves': 'Vanalar',
    'zone controllers': 'Zon Kontrolörleri',
  };
  return labels[key] ?? (category.isEmpty ? 'Kategorisiz' : category);
}
