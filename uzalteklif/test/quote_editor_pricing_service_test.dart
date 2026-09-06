import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/market_rate.dart';
import 'package:uzalteklif/services/quote_editor_pricing_service.dart';

void main() {
  test('pricing service converts totals without UI state', () {
    const service = QuoteEditorPricingService();
    final rates = [
      MarketRate(
        code: 'USDTRY',
        label: 'Dolar',
        unitLabel: '1 USD',
        value: 40,
        updatedAt: DateTime(2026, 1, 1),
      ),
    ];
    expect(
      service.convertedTotal(
        subtotalTl: 400,
        displayUnit: 'USDTRY',
        rates: rates,
      ),
      10,
    );
    expect(
      service.convertedTotal(subtotalTl: 400, displayUnit: 'TL', rates: rates),
      400,
    );
  });
}
