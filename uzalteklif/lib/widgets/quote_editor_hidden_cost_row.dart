import 'package:flutter/material.dart';

class QuoteEditorHiddenCostRow extends StatelessWidget {
  const QuoteEditorHiddenCostRow({
    super.key,
    required this.name,
    required this.amountText,
    required this.parameterTexts,
    required this.onEdit,
    required this.onRemove,
  });

  final String name;
  final String amountText;
  final List<String> parameterTexts;
  final VoidCallback onEdit;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    const purple = Color(0xFF4A2C80);
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: Colors.white.withValues(alpha: 0.9),
        border: Border.all(color: const Color(0xFFD6C8EC)),
      ),
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  name.isEmpty ? 'Ek Yukleme' : name,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    color: purple,
                  ),
                ),
              ),
              Text(
                amountText,
                style: const TextStyle(
                  color: purple,
                  fontWeight: FontWeight.w800,
                ),
              ),
              IconButton(
                tooltip: 'Duzenle',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_rounded, size: 18),
              ),
              IconButton(
                tooltip: 'Sil',
                onPressed: onRemove,
                icon: const Icon(Icons.delete_outline_rounded, size: 18),
              ),
            ],
          ),
          if (parameterTexts.isNotEmpty)
            Wrap(
              spacing: 8,
              runSpacing: 6,
              children: [
                for (final text in parameterTexts)
                  Chip(label: Text(text), visualDensity: VisualDensity.compact),
              ],
            ),
        ],
      ),
    );
  }
}
