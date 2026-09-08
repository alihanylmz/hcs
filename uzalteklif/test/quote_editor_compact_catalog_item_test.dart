import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/product.dart';
import 'package:uzalteklif/widgets/quote_editor_compact_catalog_item.dart';

void main() {
  testWidgets('renders compact catalog item', (tester) async {
    final product = Product(
      id: 'p1',
      code: 'P-1',
      name: 'Pompa',
      category: 'Genel',
      brand: 'M',
      model: '1',
      unit: 'adet',
      currencyCode: 'TL',
      salePrice: 100,
      stockQuantity: 2,
      minimumStock: 1,
      vatRate: 20,
      leadTime: '',
      description: '',
      technicalSummary: '',
      isActive: true,
      updatedAt: DateTime(2026),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: QuoteEditorCompactCatalogItem(
            product: product,
            selected: false,
            onAdd: () {},
          ),
        ),
      ),
    );
    expect(find.text('Pompa'), findsOneWidget);
    expect(find.text('Kaleme Al'), findsOneWidget);
  });
}
