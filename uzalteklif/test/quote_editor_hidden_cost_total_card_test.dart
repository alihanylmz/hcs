import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_hidden_cost_total_card.dart';

void main() {
  testWidgets('renders hidden cost total', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuoteEditorHiddenCostTotalCard(amountText: '500 TL'),
        ),
      ),
    );
    expect(find.text('500 TL'), findsOneWidget);
    expect(find.textContaining('PDF'), findsOneWidget);
  });
}
