import 'package:flutter/material.dart';

class QuoteEditorInfoSummary extends StatelessWidget {
  const QuoteEditorInfoSummary({super.key, required this.values});

  final List<String> values;

  @override
  Widget build(BuildContext context) {
    final summary = values.isEmpty
        ? 'Henüz bilgi girilmedi. Butona basarak açabilirsin.'
        : values.join(' · ');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        color: const Color(0xFFEEF3F8),
        border: Border.all(color: const Color(0xFFD7DEE6)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 18,
            color: Color(0xFF17304C),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: const Color(0xFF17304C),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
