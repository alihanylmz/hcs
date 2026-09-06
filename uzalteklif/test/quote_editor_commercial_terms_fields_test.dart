import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_commercial_terms_fields.dart';

void main() {
  testWidgets('renders and binds all commercial term fields', (tester) async {
    final validity = TextEditingController(text: '15 gun');
    final delivery = TextEditingController(text: 'Depoda teslim');
    final payment = TextEditingController(text: '30 gun');
    addTearDown(validity.dispose);
    addTearDown(delivery.dispose);
    addTearDown(payment.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorCommercialTermsFields(
            validityController: validity,
            deliveryTermsController: delivery,
            paymentTermsController: payment,
          ),
        ),
      ),
    );

    expect(find.text('Teklif Gecerliligi'), findsOneWidget);
    expect(find.text('Teslim Kosulu'), findsOneWidget);
    expect(find.text('Odeme Kosulu'), findsOneWidget);
    expect(find.text('15 gun'), findsOneWidget);
  });
}
