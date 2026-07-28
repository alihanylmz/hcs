import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/discovery_project.dart';
import 'package:uzalteklif/models/product.dart';
import 'package:uzalteklif/utils/discovery_product_matcher.dart';
import 'package:uzalteklif/utils/product_category_labels.dart';

void main() {
  test('İngilizce stok kategorileri Türkçe gösterilir', () {
    expect(productCategoryTurkishLabel('Accessories'), 'Aksesuarlar');
    expect(
      productCategoryTurkishLabel('Plant Controllers w/ Onboard IO'),
      'Dahili I/O’lu Tesis Kontrolörleri',
    );
    expect(productCategoryTurkishLabel('Dedicated IO'), 'Özel I/O Modülleri');
  });

  test('HMI ve HMIs aynı Türkçe kategoriye birleşir', () {
    expect(
      productCategoryTurkishLabel('HMI'),
      productCategoryTurkishLabel('HMIs'),
    );
    expect(productCategoryTurkishLabel('HMIs'), 'HMI / Operatör Panelleri');
  });

  test('sensör ürünleri adına göre Türkçe alt kategoriye ayrılır', () {
    final product = Product(
      id: 'sensor-1',
      code: 'VF20-3B54NW',
      name: 'Rod sensor, NTC20k, 300mm',
      category: 'Sensor',
      brand: 'Honeywell',
      model: 'VF20-3B54NW',
      unit: 'adet',
      currencyCode: 'EURTRY',
      salePrice: 63.25,
      stockQuantity: 4,
      minimumStock: 1,
      vatRate: 20,
      leadTime: '',
      description: 'Temperature sensor',
      technicalSummary: '',
      isActive: true,
      updatedAt: DateTime.utc(2026, 7, 28),
    );

    expect(productMainCategoryFor(product), ProductMainCategory.sensor);
    expect(productSubcategoryTurkishLabel(product), 'Sıcaklık Sensörleri');
  });

  test('explicit catalog classification overrides inferred category', () {
    final source = _product(name: 'Generic transmitter', category: 'General');
    final classified = withProductCatalogClassification(
      source,
      mainCategory: 'Sensörler',
      subcategory: 'Basınç Sensörleri',
    );

    expect(productMainCategoryTurkishLabel(classified), 'Sensörler');
    expect(productSubcategoryTurkishLabel(classified), 'Basınç Sensörleri');
  });

  test('ABB FBXi ve Honeywell Unitary 16 kontrolör olarak eşleşir', () {
    final abb = _product(name: 'ABB FBXi 8R8', category: 'Genel');
    final honeywell = _product(name: 'Honeywell Unitary 16', category: 'Genel');

    expect(
      productMatchesHardwareCategory(abb, ProductMainCategory.controller),
      isTrue,
    );
    expect(
      productMatchesHardwareCategory(honeywell, ProductMainCategory.controller),
      isTrue,
    );
  });

  test('kontrolör lisansı, servis parçası ve sıcaklık kontrolörü elenir', () {
    final license = _product(
      name: 'EAGLEHAWK NX BASIC LICENSE',
      category: 'Plant Controllers w/ Onboard IO',
    );
    final servicePart = _product(
      name: 'PUSH TERMINALS 4 WAY',
      category: 'Controller Service Parts',
    );
    final temperatureController = _product(
      name: 'Electronic remote temperature controller',
      category: 'Remote Temperature Controllers',
    );

    for (final product in [license, servicePart, temperatureController]) {
      expect(
        productMatchesHardwareCategory(product, ProductMainCategory.controller),
        isFalse,
      );
    }
    expect(
      productMainCategoryFor(temperatureController),
      ProductMainCategory.thermostat,
    );
  });

  test('tesis kontrolörü kategorisinde yalnızca fiziksel cihazlar eşleşir', () {
    final hardware = _product(
      name: 'HAWK8 NO WIFI W/O LICENSE',
      category: 'Plant Controllers w/o Onboard IO',
    );
    final pointLicense = _product(
      name: 'ADV 500 GLOBPTS 100 PBPTS + SM',
      category: 'Plant Controllers w/o Onboard IO',
    );

    expect(
      productMatchesHardwareCategory(hardware, ProductMainCategory.controller),
      isTrue,
    );
    expect(
      productMatchesHardwareCategory(
        pointLicense,
        ProductMainCategory.controller,
      ),
      isFalse,
    );
  });

  test('gerçek I/O modülü eşleşir, I/O adaptörü elenir', () {
    final module = _product(
      name: '16UIO SERIAL PUSH TB',
      category: 'Dedicated IO',
    );
    final adapter = _product(
      name: 'I/O ADAPTORS PWR&COM',
      category: 'Dedicated IO',
    );

    expect(
      productMatchesHardwareCategory(module, ProductMainCategory.ioModule),
      isTrue,
    );
    expect(
      productMatchesHardwareCategory(adapter, ProductMainCategory.ioModule),
      isFalse,
    );
  });

  test('elle verilen donanım kategorisi otomatik elemenin önüne geçer', () {
    final classified = withProductCatalogClassification(
      _product(name: 'Özel haberleşme kartı', category: 'Genel'),
      mainCategory: 'I/O Modülleri',
      subcategory: 'Remote I/O Modülleri',
    );

    expect(
      productMatchesHardwareCategory(classified, ProductMainCategory.ioModule),
      isTrue,
    );
  });

  test('temperature discovery point matches classified temperature sensor', () {
    final point = DiscoveryPoint(
      id: 'point-1',
      name: 'ÜFLEME HAVASI SICAKLIĞI',
      type: DiscoveryPointType.aiPassive,
    );
    final product = withProductCatalogClassification(
      _product(name: 'Duct sensor', category: 'General'),
      mainCategory: 'Sensörler',
      subcategory: 'Sıcaklık Sensörleri',
    );

    final recommendation = recommendationForDiscoveryPoint(point);

    expect(recommendation.matches(product), isTrue);
  });

  test('discovery point keeps placed product in json', () {
    const point = DiscoveryPoint(
      id: 'point-1',
      name: 'Kazan gidiş suyu sıcaklığı',
      type: DiscoveryPointType.aiPassive,
      productId: 'product-42',
    );

    final restored = DiscoveryPoint.fromJson(point.toJson());

    expect(restored.productId, 'product-42');
  });
}

Product _product({required String name, required String category}) {
  return Product(
    id: 'product-test',
    code: 'TEST-01',
    name: name,
    category: category,
    brand: 'Test',
    model: 'T1',
    unit: 'adet',
    currencyCode: 'TL',
    salePrice: 1,
    stockQuantity: 1,
    minimumStock: 0,
    vatRate: 20,
    leadTime: '',
    description: '',
    technicalSummary: '',
    isActive: true,
    updatedAt: DateTime.utc(2026, 7, 28),
  );
}
