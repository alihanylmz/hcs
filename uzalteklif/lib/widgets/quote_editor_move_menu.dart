import 'package:flutter/material.dart';

class QuoteEditorMoveTarget {
  const QuoteEditorMoveTarget({required this.id, required this.label});
  final String id;
  final String label;
}

class QuoteEditorMoveMenu extends StatelessWidget {
  const QuoteEditorMoveMenu({
    super.key,
    required this.targets,
    required this.onSelected,
    required this.color,
  });

  final List<QuoteEditorMoveTarget> targets;
  final ValueChanged<String> onSelected;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (targets.isEmpty) return const SizedBox.shrink();
    return PopupMenuButton<String>(
      tooltip: 'Kategoriye tasi',
      icon: Icon(Icons.drive_file_move_outline, color: color, size: 20),
      onSelected: onSelected,
      itemBuilder: (_) => [
        for (final target in targets)
          PopupMenuItem<String>(
            value: target.id,
            child: Row(
              children: [
                Icon(
                  target.id.isEmpty
                      ? Icons.label_off_outlined
                      : Icons.folder_rounded,
                  size: 16,
                  color: const Color(0xFF5B6F7F),
                ),
                const SizedBox(width: 8),
                Text(target.label),
              ],
            ),
          ),
      ],
    );
  }
}
