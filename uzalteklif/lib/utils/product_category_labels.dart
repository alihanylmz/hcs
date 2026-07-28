import '../models/product.dart';

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

ProductMainCategory productMainCategoryFor(Product product) {
  final searchable = [product.category, product.name].join(' ').toLowerCase();
  if (searchable.contains('accessor')) return ProductMainCategory.accessory;
  if (searchable.contains('hmi') ||
      searchable.contains('operator panel') ||
      searchable.contains('operatör panel')) {
    return ProductMainCategory.hmi;
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
      searchable.contains('kontrolör') ||
      searchable.contains('kontrolor')) {
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

String productSubcategoryTurkishLabel(Product product) {
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
