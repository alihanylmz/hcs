import 'package:flutter/material.dart';

import '../models/product.dart';
import '../utils/product_category_labels.dart';

class QuoteEditorCatalogRow extends StatelessWidget {
  const QuoteEditorCatalogRow({
    super.key,
    required this.product,
    required this.selected,
    required this.onAdd,
  });

  final Product product;
  final bool selected;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final body = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.84),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 136,
            child: Text(
              product.code,
              overflow: TextOverflow.ellipsis,
              style: body.bodyMedium?.copyWith(
                color: const Color(0xFF17304C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  overflow: TextOverflow.ellipsis,
                  style: body.bodyMedium?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 4),
                Text(
                  '${product.brand} - ${product.model} - ${productSubcategoryTurkishLabel(product)}',
                  overflow: TextOverflow.ellipsis,
                  style: body.bodySmall?.copyWith(
                    color: const Color(0xFF5B6F7F),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 108,
            child: Text(
              product.formattedStock,
              overflow: TextOverflow.ellipsis,
              style: body.bodyMedium?.copyWith(
                color: product.isLowStock
                    ? const Color(0xFF9D5C1D)
                    : const Color(0xFF17304C),
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 132,
            child: Text(
              product.formattedSalePrice,
              textAlign: TextAlign.end,
              overflow: TextOverflow.ellipsis,
              style: body.bodyMedium?.copyWith(
                color: const Color(0xFF17304C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 106,
            child: OutlinedButton(
              key: ValueKey('catalog-add-${product.id}'),
              onPressed: onAdd,
              child: Text(selected ? 'Arttir' : 'Kaleme Al'),
            ),
          ),
        ],
      ),
    );
  }
}
