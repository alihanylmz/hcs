import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../models/personal_note.dart';

/// Calisma Masasi'ndaki serbest not defteri / ajanda / hatirlatici karti.
///
/// Takvimdeki gunlere baglanmis kayitlari da (ajanda/hatirlatici) burada
/// tek listede gosterir; tarihsiz olanlar "Not Defteri" gibi calisir.
class PersonalNotesCard extends StatelessWidget {
  const PersonalNotesCard({
    super.key,
    required this.notes,
    required this.onAdd,
    required this.onToggleDone,
    required this.onDelete,
    required this.onEdit,
  });

  final List<PersonalNote> notes;
  final VoidCallback onAdd;
  final ValueChanged<PersonalNote> onToggleDone;
  final ValueChanged<PersonalNote> onDelete;
  final ValueChanged<PersonalNote> onEdit;

  static const _ink = Color(0xFF17304C);
  static const _slate = Color(0xFF5B6F7F);
  static const _noteColor = Color(0xFF3F8F5C);

  @override
  Widget build(BuildContext context) {
    // Tamamlanmamis + tarihe yakin olanlar once; tamamlanmislar en altta.
    final sorted = [...notes]
      ..sort((a, b) {
        if (a.isDone != b.isDone) return a.isDone ? 1 : -1;
        final ad = a.noteDate;
        final bd = b.noteDate;
        if (ad != null && bd != null) return ad.compareTo(bd);
        if (ad != null) return -1;
        if (bd != null) return 1;
        return b.createdAt.compareTo(a.createdAt);
      });

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: Color(0xFFD7DEE6)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.sticky_note_2_rounded, size: 18, color: _ink),
                const SizedBox(width: 8),
                const Expanded(
                  child: Text(
                    'Notlarim - Ajanda / Hatirlatici',
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 14,
                      color: _ink,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('notes-add'),
                  tooltip: 'Yeni not / hatirlatici ekle',
                  onPressed: onAdd,
                  icon: const Icon(Icons.add_circle_outline, color: _noteColor),
                ),
              ],
            ),
            const SizedBox(height: 4),
            if (sorted.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Henuz not yok. Serbest bir not, tarihli bir ajanda '
                  'kaydi ya da hatirlatici eklemek icin + butonuna dokunun.',
                  style: TextStyle(fontSize: 12, color: _slate),
                ),
              )
            else
              for (final note in sorted) _row(context, note),
          ],
        ),
      ),
    );
  }

  Widget _row(BuildContext context, PersonalNote note) {
    final dateLabel = note.noteDate == null
        ? null
        : DateFormat('d MMMM', 'tr_TR').format(note.noteDate!);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => onToggleDone(note),
            child: Icon(
              note.isDone
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              size: 18,
              color: note.isDone ? _noteColor : _slate,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: InkWell(
              onTap: () => onEdit(note),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          note.title.trim().isEmpty
                              ? '(basliksiz not)'
                              : note.title,
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: _ink,
                            decoration: note.isDone
                                ? TextDecoration.lineThrough
                                : null,
                          ),
                        ),
                      ),
                      if (note.isReminder)
                        const Padding(
                          padding: EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.notifications_active_rounded,
                            size: 14,
                            color: _noteColor,
                          ),
                        ),
                      if (dateLabel != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text(
                            dateLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: _noteColor,
                            ),
                          ),
                        ),
                    ],
                  ),
                  if (note.body.trim().isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        note.body.trim(),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 12, color: _slate),
                      ),
                    ),
                ],
              ),
            ),
          ),
          InkWell(
            onTap: () => onDelete(note),
            child: const Padding(
              padding: EdgeInsets.only(left: 6, top: 2),
              child: Icon(Icons.close_rounded, size: 16, color: _slate),
            ),
          ),
        ],
      ),
    );
  }
}
