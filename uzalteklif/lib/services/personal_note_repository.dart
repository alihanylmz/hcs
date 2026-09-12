import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/personal_note.dart';

/// Calisma Masasi'ndaki ajanda / not defteri / hatirlatici kayitlarini
/// yonetir. Supabase bagli degilse (offline / test) bellek icinde tutar,
/// tipki diger repository'lerin yaptigi gibi.
class PersonalNoteRepository {
  PersonalNoteRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  static final List<PersonalNote> _memoryNotes = [];

  bool get _remoteReady =>
      _client != null && _client.auth.currentSession != null;

  Future<List<PersonalNote>> fetchMine() async {
    if (!_remoteReady) {
      return List.unmodifiable(_memoryNotes);
    }
    final uid = _client!.auth.currentUser?.id;
    if (uid == null) return const [];
    try {
      final rows = await _client
          .from('personal_notes')
          .select()
          .eq('user_id', uid)
          .order('note_date', ascending: true)
          .order('created_at', ascending: false);
      return rows
          .cast<Map<String, dynamic>>()
          .map(PersonalNote.fromRow)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<PersonalNote> create(PersonalNote note) async {
    if (!_remoteReady) {
      final created = PersonalNote(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        title: note.title,
        body: note.body,
        noteDate: note.noteDate,
        isReminder: note.isReminder,
        isDone: note.isDone,
        createdAt: DateTime.now(),
      );
      _memoryNotes.add(created);
      return created;
    }
    final uid = _client!.auth.currentUser?.id;
    if (uid == null) {
      throw StateError('Not eklemek icin giris yapmis olmaniz gerekiyor.');
    }
    final row = await _client
        .from('personal_notes')
        .insert(note.toInsertRow(uid))
        .select()
        .single();
    return PersonalNote.fromRow(Map<String, dynamic>.from(row));
  }

  Future<void> update(PersonalNote note) async {
    if (!_remoteReady) {
      final idx = _memoryNotes.indexWhere((n) => n.id == note.id);
      if (idx != -1) _memoryNotes[idx] = note;
      return;
    }
    await _client!
        .from('personal_notes')
        .update({
          'title': note.title,
          'body': note.body,
          'note_date': note.noteDate == null
              ? null
              : '${note.noteDate!.year.toString().padLeft(4, '0')}-'
                    '${note.noteDate!.month.toString().padLeft(2, '0')}-'
                    '${note.noteDate!.day.toString().padLeft(2, '0')}',
          'is_reminder': note.isReminder,
          'is_done': note.isDone,
        })
        .eq('id', note.id);
  }

  Future<void> delete(String id) async {
    if (!_remoteReady) {
      _memoryNotes.removeWhere((n) => n.id == id);
      return;
    }
    await _client!.from('personal_notes').delete().eq('id', id);
  }
}
