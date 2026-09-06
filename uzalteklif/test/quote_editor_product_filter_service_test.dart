import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/product.dart';
import 'package:uzalteklif/services/quote_editor_product_filter_service.dart';

void main() {
  test('product filter matches normalized Turkish text and category', () {
    const service = QuoteEditorProductFilterService();
    final product = Product(
      id: 'p1',
      code: 'SNS-1',
      name: 'Sıcaklık Sensörü',
      category: 'Sensor',
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
      updatedAt: DateTime(2026),
    );
    expect(
      service.filter([product], query: 'sicaklik', category: 'Sensor'),
      hasLength(1),
    );
    expect(
      service.filter([product], query: 'yok', category: 'Sensor'),
      isEmpty,
    );
  });
}
