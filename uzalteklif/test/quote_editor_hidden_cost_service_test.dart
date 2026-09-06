import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/services/quote_editor_hidden_cost_service.dart';

void main() {
  test('hidden cost service calculates subtotal and uplift', () {
    const service = QuoteEditorHiddenCostService();
    expect(service.subtotal([100, 50]), 150);
    expect(
      service.upliftFactor(visibleSubtotalTl: 1000, hiddenSubtotalTl: 250),
      1.25,
    );
  });
}
