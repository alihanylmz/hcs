import '../models/market_rate.dart';

/// Teklif editörünün fiyat özeti hesaplarını UI'dan ayırır.
class QuoteEditorPricingService {
  const QuoteEditorPricingService();

  MarketRate? selectedRate(String displayUnit, List<MarketRate> rates) {
    if (displayUnit == 'TL') return null;
    for (final rate in rates) {
      if (rate.code == displayUnit) return rate;
    }
    return rates.isEmpty ? null : rates.first;
  }

  double convertedTotal({
    required double subtotalTl,
    required String displayUnit,
    required List<MarketRate> rates,
  }) {
    final rate = selectedRate(displayUnit, rates);
    if (rate == null || rate.value == 0) return subtotalTl;
    return subtotalTl / rate.value;
  }
}
