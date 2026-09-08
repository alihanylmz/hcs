import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_line_unit_field.dart';

void main() {
  testWidgets('binds the line unit controller', (tester) async {
    final controller = TextEditingController(text: 'adet');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorLineUnitField(
            controller: controller,
            validator: (_) => null,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('adet'), findsOneWidget);
  });
}
