import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_line_description_field.dart';

void main() {
  testWidgets('binds the line description controller', (tester) async {
    final controller = TextEditingController(text: 'Servis');
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorLineDescriptionField(
            controller: controller,
            validator: (_) => null,
            onChanged: (_) {},
          ),
        ),
      ),
    );
    expect(find.text('Servis'), findsOneWidget);
  });
}
