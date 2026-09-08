import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_line_unit_price_field.dart';

void main() {
  testWidgets('binds unit price and displays currency label', (tester) async {
    final controller = TextEditingController(text: '100');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorLineUnitPriceField(
            controller: controller,
            validator: (_) => null,
            onChanged: (_) {},
            currencyLabel: 'USD',
          ),
        ),
      ),
    );
    expect(find.text('Birim Fiyat (USD)'), findsOneWidget);
    expect(find.text('100'), findsOneWidget);
  });
}
