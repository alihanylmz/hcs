import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/quote.dart';
import 'package:uzalteklif/widgets/quote_editor_payment_visibility_panel.dart';

void main() {
  testWidgets('renders payment and price visibility controls', (tester) async {
    final days = TextEditingController(text: '30');
    addTearDown(days.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorPaymentVisibilityPanel(
            paymentMethod: QuotePaymentMethod.cash,
            paymentTermDaysController: days,
            hidePrices: false,
            onPaymentMethodChanged: (_) {},
            onHidePricesChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Odeme Yontemi'), findsOneWidget);
    expect(find.text('Fiyatlari Gizle'), findsOneWidget);
  });
}
