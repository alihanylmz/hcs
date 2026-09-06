import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/services/quote_editor_line_total_service.dart';

void main() {
  const service = QuoteEditorLineTotalService();

  test('calculates quantity, TL unit price and discount', () {
    expect(
      service.netTotal(quantity: 5, unitPriceTl: 100, discountRate: 10),
      450,
    );
  });

  test('keeps zero discount unchanged', () {
    expect(
      service.netTotal(quantity: 2, unitPriceTl: 125.5, discountRate: 0),
      251,
    );
  });

  test('preserves existing behavior for discounts above 100 percent', () {
    expect(
      service.netTotal(quantity: 1, unitPriceTl: 100, discountRate: 150),
      -50,
    );
  });
}
