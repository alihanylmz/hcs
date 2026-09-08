import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/product.dart';
import 'package:uzalteklif/widgets/quote_editor_product_catalog.dart';

void main() {
  testWidgets('renders empty product catalog state', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: QuoteEditorProductCatalog(
            allProducts: [],
            filteredProducts: [],
            isSelected: _neverSelected,
            onAdd: _ignoreProduct,
          ),
        ),
      ),
    );
    expect(
      find.text('Katalogda gosterilecek urun bulunmuyor.'),
      findsOneWidget,
    );
  });
}

bool _neverSelected(String _) => false;
void _ignoreProduct(Product _) {}
