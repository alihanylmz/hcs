import 'package:flutter_test/flutter_test.dart';
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
}
