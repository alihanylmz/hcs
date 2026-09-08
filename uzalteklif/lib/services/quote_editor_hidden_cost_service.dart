/// Gizli maliyet toplamını editör widget'ından ayırır.
class QuoteEditorHiddenCostService {
  const QuoteEditorHiddenCostService();

  double subtotal(Iterable<double> totals) =>
      totals.fold(0, (sum, total) => sum + total);

  double upliftFactor({
    required double visibleSubtotalTl,
    required double hiddenSubtotalTl,
  }) {
    if (visibleSubtotalTl <= 0) return 1;
    return (visibleSubtotalTl + hiddenSubtotalTl) / visibleSubtotalTl;
  }
}
