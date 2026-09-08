import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_catalog_label.dart';

void main() {
  testWidgets('renders catalog label', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Scaffold(body: QuoteEditorCatalogLabel('Kod'))),
    );
    expect(find.text('Kod'), findsOneWidget);
  });
}
