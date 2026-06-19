import 'dart:convert';

class TicketFaultLinkCandidate {
  const TicketFaultLinkCandidate({
    required this.id,
    required this.jobCode,
    required this.title,
    required this.status,
    this.createdAt,
  });

  final String id;
  final String jobCode;
  final String title;
  final String status;
  final DateTime? createdAt;

  factory TicketFaultLinkCandidate.fromJson(Map<String, dynamic> json) {
    return TicketFaultLinkCandidate(
      id: json['id']?.toString() ?? '',
      jobCode: json['job_code']?.toString() ?? '',
      title: json['title']?.toString() ?? 'Basliksiz is',
      status: json['status']?.toString() ?? 'open',
      createdAt: DateTime.tryParse(json['created_at']?.toString() ?? ''),
    );
  }

  String get displayTitle {
    final normalizedJobCode = jobCode.trim();
    if (normalizedJobCode.isEmpty) return title;
    return '$normalizedJobCode - $title';
  }
}

class TicketFaultRecord {
  static const String structuredRecordTypeKey = 'system_record_type';
  static const String noteType = 'fault_record';
  static const String legacyStorageNoteType = 'service_note';

  const TicketFaultRecord({
    required this.id,
    required this.ticketId,
    required this.faultCode,
    required this.faultTitle,
    required this.faultBody,
    this.deviceBrand,
    this.deviceModel,
    this.assigneeId,
    this.assigneeName,
    this.createdAt,
    this.createdByName,
  });

  final String id;
  final String ticketId;
  final String faultCode;
  final String faultTitle;
  final String faultBody;
  final String? deviceBrand;
  final String? deviceModel;
  final String? assigneeId;
  final String? assigneeName;
  final DateTime? createdAt;
  final String? createdByName;

  static bool isFaultRecordNote(Map<String, dynamic> note) {
    final currentNoteType = note['note_type']?.toString() ?? '';
    if (currentNoteType == noteType) {
      return true;
    }
    if (currentNoteType != legacyStorageNoteType) {
      return false;
    }

    final payload = _decodePayload(note['note']);
    return payload[structuredRecordTypeKey]?.toString() == noteType;
  }

  factory TicketFaultRecord.fromTicketNote(Map<String, dynamic> note) {
    final payload = _decodePayload(note['note']);
    final profile = note['profiles'];
    final profileMap =
        profile is Map
            ? Map<String, dynamic>.from(profile)
            : const <String, dynamic>{};
    final faultCode = payload['fault_code']?.toString().trim();
    final faultTitle = payload['fault_title']?.toString().trim();
    final faultBody = payload['fault_body']?.toString().trim();

    return TicketFaultRecord(
      id: note['id']?.toString() ?? '',
      ticketId: note['ticket_id']?.toString() ?? '',
      faultCode: (faultCode == null || faultCode.isEmpty) ? '-' : faultCode,
      faultTitle:
          (faultTitle == null || faultTitle.isEmpty)
              ? 'Ariza kaydi'
              : faultTitle,
      faultBody:
          (faultBody == null || faultBody.isEmpty)
              ? 'Aciklama girilmemis.'
              : faultBody,
      deviceBrand: payload['device_brand']?.toString(),
      deviceModel: payload['device_model']?.toString(),
      assigneeId: payload['assignee_id']?.toString(),
      assigneeName: payload['assignee_name']?.toString(),
      createdAt: DateTime.tryParse(note['created_at']?.toString() ?? ''),
      createdByName: profileMap['full_name']?.toString(),
    );
  }

  String get deviceLabel {
    final brand = deviceBrand?.trim() ?? '';
    final model = deviceModel?.trim() ?? '';
    if (brand.isEmpty && model.isEmpty) {
      return 'Cihaz bilgisi yok';
    }
    if (brand.isEmpty) return model;
    if (model.isEmpty) return brand;
    return '$brand / $model';
  }

  static Map<String, dynamic> _decodePayload(dynamic rawValue) {
    if (rawValue is Map<String, dynamic>) {
      return rawValue;
    }
    if (rawValue is Map) {
      return Map<String, dynamic>.from(rawValue);
    }

    final rawText = rawValue?.toString().trim() ?? '';
    if (rawText.isEmpty) {
      return const {};
    }

    try {
      final decoded = jsonDecode(rawText);
      if (decoded is Map<String, dynamic>) {
        return decoded;
      }
      if (decoded is Map) {
        return Map<String, dynamic>.from(decoded);
      }
    } catch (_) {
      return {'fault_body': rawText};
    }

    return {'fault_body': rawText};
  }
}
