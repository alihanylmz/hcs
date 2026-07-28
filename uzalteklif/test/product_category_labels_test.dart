import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/product.dart';
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
}
