import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_hidden_cost_row.dart';

void main() {
  testWidgets('renders hidden cost row actions and amount', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorHiddenCostRow(
            name: 'Mobilizasyon',
            amountText: '1.000 TL',
            parameterTexts: const ['Gun: 1'],
            onEdit: () {},
            onRemove: () {},
          ),
        ),
      ),
    );
    expect(find.text('Mobilizasyon'), findsOneWidget);
    expect(find.text('1.000 TL'), findsOneWidget);
  });
}
