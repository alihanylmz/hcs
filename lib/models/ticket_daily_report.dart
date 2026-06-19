import 'dart:convert';

class TicketDailyReport {
  static const String structuredRecordTypeKey = 'system_record_type';
  static const String noteType = 'daily_report';
  static const String legacyStorageNoteType = 'service_note';

  const TicketDailyReport({
    required this.id,
    required this.ticketId,
    required this.reportDate,
    required this.technicianName,
    required this.startTime,
    required this.endTime,
    required this.workDone,
    required this.issues,
    required this.usedMaterials,
    required this.nextStep,
    required this.customerApproval,
    this.createdAt,
    this.createdByName,
  });

  final String id;
  final String ticketId;
  final DateTime reportDate;
  final String technicianName;
  final String startTime;
  final String endTime;
  final String workDone;
  final String issues;
  final String usedMaterials;
  final String nextStep;
  final bool customerApproval;
  final DateTime? createdAt;
  final String? createdByName;

  String get title {
    final day = reportDate.day.toString().padLeft(2, '0');
    final month = reportDate.month.toString().padLeft(2, '0');
    return '$day.$month.${reportDate.year} Gunluk Rapor';
  }

  String get timeRange {
    final start = startTime.trim();
    final end = endTime.trim();
    if (start.isEmpty && end.isEmpty) return '-';
    if (start.isEmpty) return end;
    if (end.isEmpty) return start;
    return '$start - $end';
  }

  Map<String, dynamic> toPayload() {
    return {
      structuredRecordTypeKey: noteType,
      'report_date': reportDate.toIso8601String(),
      'technician_name': technicianName.trim(),
      'start_time': startTime.trim(),
      'end_time': endTime.trim(),
      'work_done': workDone.trim(),
      'issues': issues.trim(),
      'used_materials': usedMaterials.trim(),
      'next_step': nextStep.trim(),
      'customer_approval': customerApproval,
    };
  }

  String toStorageText() => jsonEncode(toPayload());

  static bool isDailyReportNote(Map<String, dynamic> note) {
    final currentNoteType = note['note_type']?.toString() ?? '';
    if (currentNoteType == noteType) return true;
    if (currentNoteType != legacyStorageNoteType) return false;

    final payload = _parsePayload(note['note']);
    return payload[structuredRecordTypeKey]?.toString() == noteType;
  }

  factory TicketDailyReport.fromTicketNote(Map<String, dynamic> note) {
    final payload = _parsePayload(note['note']);
    final profile = note['profiles'];
    final profileMap =
        profile is Map
            ? Map<String, dynamic>.from(profile)
            : const <String, dynamic>{};
    final createdAt = DateTime.tryParse(note['created_at']?.toString() ?? '');
    final reportDate =
        DateTime.tryParse(payload['report_date']?.toString() ?? '') ??
        createdAt ??
        DateTime.now();

    return TicketDailyReport(
      id: note['id']?.toString() ?? '',
      ticketId: note['ticket_id']?.toString() ?? '',
      reportDate: reportDate,
      technicianName: payload['technician_name']?.toString() ?? '',
      startTime: payload['start_time']?.toString() ?? '',
      endTime: payload['end_time']?.toString() ?? '',
      workDone: payload['work_done']?.toString() ?? '',
      issues: payload['issues']?.toString() ?? '',
      usedMaterials: payload['used_materials']?.toString() ?? '',
      nextStep: payload['next_step']?.toString() ?? '',
      customerApproval: payload['customer_approval'] == true,
      createdAt: createdAt,
      createdByName: profileMap['full_name']?.toString(),
    );
  }

  static Map<String, dynamic> _parsePayload(dynamic rawNote) {
    if (rawNote is Map<String, dynamic>) return rawNote;
    if (rawNote is Map) return Map<String, dynamic>.from(rawNote);
    if (rawNote is String && rawNote.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawNote);
        if (decoded is Map<String, dynamic>) return decoded;
        if (decoded is Map) return Map<String, dynamic>.from(decoded);
      } catch (_) {
        return const <String, dynamic>{};
      }
    }
    return const <String, dynamic>{};
  }
}
