import 'package:flutter/material.dart';

/// Katalogda urun isaretlendiginde katalogun ustunde beliren toplu islem
/// cubugu. Hicbir sey isaretli degilken hic cizilmez.
class QuoteEditorCatalogSelectionBar extends StatelessWidget {
  const QuoteEditorCatalogSelectionBar({
    super.key,
    required this.selectedCount,
    required this.onAddSelected,
    required this.onClear,
  });

  final int selectedCount;
  final VoidCallback onAddSelected;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    if (selectedCount == 0) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF17304C).withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: const Color(0xFF17304C).withValues(alpha: 0.18),
          ),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.checklist_rounded,
              size: 18,
              color: Color(0xFF17304C),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$selectedCount urun secildi',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF17304C),
                ),
              ),
            ),
            TextButton(
              key: const ValueKey('catalog-selection-clear'),
              onPressed: onClear,
              child: const Text('Temizle'),
            ),
            const SizedBox(width: 6),
            FilledButton.icon(
              key: const ValueKey('catalog-selection-add'),
              onPressed: onAddSelected,
              icon: const Icon(Icons.playlist_add_rounded, size: 18),
              label: const Text('Secilenleri ekle'),
            ),
          ],
        ),
      ),
    );
  }
}
