import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/widgets/quote_editor_product_catalog_empty_state.dart';

void main() {
  testWidgets('renders product catalog empty message', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuoteEditorProductCatalogEmptyState(message: 'Urun yok'),
        ),
      ),
    );
    expect(find.text('Urun yok'), findsOneWidget);
  });
}
