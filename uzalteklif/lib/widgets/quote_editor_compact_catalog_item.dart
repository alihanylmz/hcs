import 'package:flutter/material.dart';

import '../models/product.dart';
import '../utils/product_category_labels.dart';

class QuoteEditorCompactCatalogItem extends StatelessWidget {
  const QuoteEditorCompactCatalogItem({
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
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.84),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              OutlinedButton(
                key: ValueKey('catalog-add-${product.id}'),
                onPressed: onAdd,
                child: Text(selected ? 'Arttir' : 'Kaleme Al'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '${product.code} - ${product.brand} ${product.model}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: textTheme.bodySmall?.copyWith(
              color: const Color(0xFF5B6F7F),
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _InfoPill(label: productSubcategoryTurkishLabel(product)),
              _InfoPill(label: product.formattedStock),
              _InfoPill(label: product.formattedSalePrice),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoPill extends StatelessWidget {
  const _InfoPill({required this.label});
  final String label;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(999),
      color: const Color(0xFFF5F8FB),
      border: Border.all(color: const Color(0xFFD7DEE6)),
    ),
    child: Text(
      label,
      style: Theme.of(
        context,
      ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w700),
    ),
  );
}
