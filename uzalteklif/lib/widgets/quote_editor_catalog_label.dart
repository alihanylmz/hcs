import 'package:flutter/material.dart';

class QuoteEditorCatalogLabel extends StatelessWidget {
  const QuoteEditorCatalogLabel(this.label, {super.key, this.alignEnd = false});

  final String label;
  final bool alignEnd;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      textAlign: alignEnd ? TextAlign.end : TextAlign.start,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
        color: const Color(0xFF667887),
        fontWeight: FontWeight.w800,
      ),
    );
  }
}
