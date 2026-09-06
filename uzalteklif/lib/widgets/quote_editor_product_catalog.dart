import 'package:flutter/material.dart';

import '../models/product.dart';
import 'quote_editor_catalog_label.dart';
import 'quote_editor_catalog_row.dart';
import 'quote_editor_compact_catalog_item.dart';
import 'quote_editor_product_catalog_empty_state.dart';

class QuoteEditorProductCatalog extends StatelessWidget {
  const QuoteEditorProductCatalog({
    super.key,
    required this.allProducts,
    required this.filteredProducts,
    required this.isSelected,
    required this.onAdd,
  });

  final List<Product> allProducts;
  final List<Product> filteredProducts;
  final bool Function(String productId) isSelected;
  final ValueChanged<Product> onAdd;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 250,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: Colors.white.withValues(alpha: 0.74),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (allProducts.isEmpty) {
            return const QuoteEditorProductCatalogEmptyState(
              message: 'Katalogda gosterilecek urun bulunmuyor.',
            );
          }
          if (filteredProducts.isEmpty) {
            return const QuoteEditorProductCatalogEmptyState(
              message: 'Filtreye uygun urun bulunamadi.',
            );
          }
          if (constraints.maxWidth < 960) {
            return ListView.separated(
              padding: const EdgeInsets.all(12),
              itemCount: filteredProducts.length,
              separatorBuilder: (_, _) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final product = filteredProducts[index];
                return QuoteEditorCompactCatalogItem(
                  product: product,
                  selected: isSelected(product.id),
                  onAdd: () => onAdd(product),
                );
              },
            );
          }
          return Column(
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 12, 16, 10),
                child: Row(
                  children: [
                    SizedBox(width: 136, child: QuoteEditorCatalogLabel('Kod')),
                    Expanded(child: QuoteEditorCatalogLabel('Urun')),
                    SizedBox(
                      width: 108,
                      child: QuoteEditorCatalogLabel('Stok'),
                    ),
                    SizedBox(
                      width: 132,
                      child: QuoteEditorCatalogLabel('Satis', alignEnd: true),
                    ),
                    SizedBox(width: 118),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  itemCount: filteredProducts.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final product = filteredProducts[index];
                    return QuoteEditorCatalogRow(
                      product: product,
                      selected: isSelected(product.id),
                      onAdd: () => onAdd(product),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
