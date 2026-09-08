import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_hidden_cost_summary.dart';

void main() {
  testWidgets('renders hidden cost warning and amount', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuoteEditorHiddenCostSummary(amountText: '250 TL'),
        ),
      ),
    );
    expect(find.textContaining('PDF'), findsOneWidget);
    expect(find.text('250 TL'), findsOneWidget);
  });
}
