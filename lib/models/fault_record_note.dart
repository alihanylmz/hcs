class FaultRecordNote {
  const FaultRecordNote({
    required this.id,
    required this.faultRecordId,
    required this.note,
    required this.noteType,
    this.userId,
    this.userName,
    this.userRole,
    this.createdAt,
  });

  final String id;
  final String faultRecordId;
  final String note;
  final String noteType;
  final String? userId;
  final String? userName;
  final String? userRole;
  final DateTime? createdAt;

  factory FaultRecordNote.fromJson(Map<String, dynamic> json) {
    return FaultRecordNote(
      id: json['id']?.toString() ?? '',
      faultRecordId: json['fault_record_id']?.toString() ?? '',
      note: _nullableText(json['note']) ?? '',
      noteType: _nullableText(json['note_type']) ?? 'note',
      userId: _nullableText(json['user_id']),
      userName: _nullableText(json['user_name']),
      userRole: _nullableText(json['user_role']),
      createdAt: _parseDate(json['created_at']),
    );
  }

  String get authorLabel {
    final name = (userName ?? '').trim();
    return name.isEmpty ? 'Bilinmeyen kullanici' : name;
  }

  String? get roleLabel {
    switch (userRole) {
      case 'admin':
        return 'Admin';
      case 'manager':
        return 'Yonetici';
      case 'engineer':
        return 'Muhendis';
      case 'technician':
        return 'Teknisyen';
      case 'supervisor':
        return 'Supervizor';
      case 'partner_user':
        return 'Partner';
      case 'user':
        return 'Kullanici';
      default:
        return null;
    }
  }

  static String? _nullableText(dynamic value) {
    final text = value?.toString().trim() ?? '';
    return text.isEmpty ? null : text;
  }

  static DateTime? _parseDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }
}

class LinkedFaultNoteEntry {
  const LinkedFaultNoteEntry({
    required this.faultRecordId,
    required this.faultCode,
    required this.faultTitle,
    required this.note,
    required this.noteType,
    this.userName,
    this.userRole,
    this.createdAt,
  });

  final String faultRecordId;
  final String faultCode;
  final String faultTitle;
  final String note;
  final String noteType;
  final String? userName;
  final String? userRole;
  final DateTime? createdAt;
}
