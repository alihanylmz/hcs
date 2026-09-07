import 'package:flutter/material.dart';
import '../services/quote_editor_autosave_service.dart';

class QuoteEditorAutosaveStatus extends StatelessWidget {
  const QuoteEditorAutosaveStatus({required this.status, super.key});

  final QuoteAutosaveStatus status;

  @override
  Widget build(BuildContext context) {
    // Etiketler bilerek "Kaydedildi" DEMEZ. Bu gosterge yalnizca cihazdaki
    // yerel taslagi anlatiyor; teklif sisteme ancak "Taslak Olarak Kaydet"
    // veya "Teklifi Tamamla" ile girer. "Kaydedildi" yazsaydi kullanici
    // teklifi kaydettigini sanip sekmeyi kapatabilirdi.
    final (icon, label, tooltip, color) = switch (status) {
      QuoteAutosaveStatus.idle => (
        Icons.devices_rounded,
        'Taslak bu cihazda',
        'Teklif henuz sisteme kaydedilmedi. Yerel taslak yalnizca bu '
            'tarayicida saklanir.',
        Colors.blueGrey,
      ),
      QuoteAutosaveStatus.dirty || QuoteAutosaveStatus.saving => (
        Icons.schedule_rounded,
        'Taslak yazılıyor...',
        'Degisiklikler bu cihazdaki yerel taslaga yaziliyor.',
        Colors.amber,
      ),
      QuoteAutosaveStatus.saved => (
        Icons.devices_rounded,
        'Taslak bu cihazda',
        'Yerel taslak guncel. Teklifi sisteme kaydetmek icin "Taslak Olarak '
            'Kaydet" veya "Teklifi Tamamla" kullanin.',
        Colors.blueGrey,
      ),
    };

    return Tooltip(
      message: tooltip,
      child: Container(
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
      ),
    );
  }
}
