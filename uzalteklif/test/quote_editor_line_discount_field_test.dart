import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_line_discount_field.dart';

void main() {
  testWidgets('renders editable discount field', (tester) async {
    final controller = TextEditingController(text: '5');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorLineDiscountField(
            controller: controller,
            validator: (_) => null,
            onChanged: (_) {},
            locked: false,
          ),
        ),
      ),
    );
    expect(find.text('Iskonto %'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
  });
}
