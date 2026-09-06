import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_line_remove_button.dart';

void main() {
  testWidgets('renders line remove button', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: QuoteEditorLineRemoveButton(onPressed: () {})),
      ),
    );
    expect(find.byIcon(Icons.delete_outline_rounded), findsOneWidget);
  });
}
