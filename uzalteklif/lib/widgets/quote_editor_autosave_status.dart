import 'package:flutter/material.dart';
import '../services/quote_editor_autosave_service.dart';

class QuoteEditorAutosaveStatus extends StatelessWidget {
  const QuoteEditorAutosaveStatus({
    required this.status,
    super.key,
  });

  final QuoteAutosaveStatus status;

  @override
  Widget build(BuildContext context) {
    final (icon, label, color) = switch (status) {
      QuoteAutosaveStatus.idle => (
          Icons.check_circle_rounded,
          'Kaydedildi',
          Colors.green
        ),
      QuoteAutosaveStatus.dirty => (
          Icons.schedule_rounded,
          'Kaydediliyor...',
          Colors.amber
        ),
      QuoteAutosaveStatus.saving => (
          Icons.schedule_rounded,
          'Kaydediliyor...',
          Colors.amber
        ),
      QuoteAutosaveStatus.saved => (
          Icons.check_circle_rounded,
          'Kaydedildi',
          Colors.green
        ),
      QuoteAutosaveStatus.offline => (
          Icons.cloud_off_rounded,
          'Çevrimdışı',
          Colors.orange
        ),
      QuoteAutosaveStatus.conflict => (
          Icons.warning_rounded,
          'Çakışma',
          Colors.red
        ),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
