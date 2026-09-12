/// Kullanicinin Calisma Masasi'nda tuttugu serbest not / ajanda / hatirlatici
/// kaydi. Teklif verisinden bagimsizdir; kullanici elle olusturur.
///
/// - `noteDate` doluysa takvimde o gune baglanir (ajanda/hatirlatici gibi
///   davranir). Bos ise "Not Defteri" listesinde tarihsiz durur.
/// - `isReminder` true ise takvimde ayri bir renkle vurgulanir.
/// - `isDone` yalnizca hatirlatici/ajanda kayitlari icin anlamlidir; tarihsiz
///   notlarda kullanilmaz ama yine de saklanir.
class PersonalNote {
  const PersonalNote({
    required this.id,
    required this.title,
    this.body = '',
    this.noteDate,
    this.isReminder = false,
    this.isDone = false,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;
  final DateTime? noteDate;
  final bool isReminder;
  final bool isDone;
  final DateTime createdAt;

  PersonalNote copyWith({
    String? title,
    String? body,
    DateTime? noteDate,
    bool clearNoteDate = false,
    bool? isReminder,
    bool? isDone,
  }) {
    return PersonalNote(
      id: id,
      title: title ?? this.title,
      body: body ?? this.body,
      noteDate: clearNoteDate ? null : (noteDate ?? this.noteDate),
      isReminder: isReminder ?? this.isReminder,
      isDone: isDone ?? this.isDone,
      createdAt: createdAt,
    );
  }

  factory PersonalNote.fromRow(Map<String, dynamic> row) {
    final rawDate = row['note_date'] as String?;
    return PersonalNote(
      id: row['id'].toString(),
      title: (row['title'] as String?) ?? '',
      body: (row['body'] as String?) ?? '',
      noteDate: rawDate == null || rawDate.isEmpty
          ? null
          : DateTime.tryParse(rawDate),
      isReminder: (row['is_reminder'] as bool?) ?? false,
      isDone: (row['is_done'] as bool?) ?? false,
      createdAt:
          DateTime.tryParse(row['created_at']?.toString() ?? '') ??
          DateTime.now(),
    );
  }

  Map<String, dynamic> toInsertRow(String userId) {
    return {
      'user_id': userId,
      'title': title,
      'body': body,
      'note_date': noteDate == null
          ? null
          : '${noteDate!.year.toString().padLeft(4, '0')}-'
                '${noteDate!.month.toString().padLeft(2, '0')}-'
                '${noteDate!.day.toString().padLeft(2, '0')}',
      'is_reminder': isReminder,
      'is_done': isDone,
    };
  }
}
