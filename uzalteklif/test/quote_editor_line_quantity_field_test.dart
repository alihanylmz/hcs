import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_line_quantity_field.dart';

void main() {
  testWidgets('binds the line quantity controller', (tester) async {
    final controller = TextEditingController(text: '2');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorLineQuantityField(
            controller: controller,
            validator: (_) => null,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('2'), findsOneWidget);
  });
}
