/// Calculates a quote line's net total after discount.
///
/// Currency conversion is intentionally handled by the editor before calling
/// this service so the calculation remains independent from UI state.
class QuoteEditorLineTotalService {
  const QuoteEditorLineTotalService();

  double netTotal({
    required double quantity,
    required double unitPriceTl,
    required double discountRate,
  }) {
    final discountRatio = discountRate / 100;
    return quantity * unitPriceTl * (1 - discountRatio);
  }
}
