import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/product.dart';
import 'package:uzalteklif/widgets/quote_editor_catalog_row.dart';

void main() {
  testWidgets('renders catalog product row', (tester) async {
    final product = Product(
      id: 'p1',
      code: 'P-1',
      name: 'Pompa',
      brand: 'Marka',
      model: 'M1',
      category: 'Genel',
      unit: 'adet',
      currencyCode: 'TL',
      salePrice: 100,
      stockQuantity: 5,
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
          body: QuoteEditorCatalogRow(
            product: product,
            selected: false,
            onAdd: () {},
          ),
        ),
      ),
    );
    expect(find.text('P-1'), findsOneWidget);
    expect(find.text('Kaleme Al'), findsOneWidget);
  });
}
