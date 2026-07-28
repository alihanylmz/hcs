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
    final source = _product(
      name: 'Generic transmitter',
      category: 'General',
    );
    final classified = withProductCatalogClassification(
      source,
      mainCategory: 'Sensörler',
      subcategory: 'Basınç Sensörleri',
    );

    expect(productMainCategoryTurkishLabel(classified), 'Sensörler');
    expect(
      productSubcategoryTurkishLabel(classified),
      'Basınç Sensörleri',
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
