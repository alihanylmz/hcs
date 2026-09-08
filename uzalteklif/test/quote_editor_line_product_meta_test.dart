import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_line_product_meta.dart';

void main() {
  testWidgets('renders line product metadata', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: QuoteEditorLineProductMeta(text: 'Marka · Model')),
      ),
    );
    expect(find.text('Marka · Model'), findsOneWidget);
  });
}
