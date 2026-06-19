import 'dart:convert';

import 'ticket_fault_record.dart';

enum TicketBackupIndicatorState { none, backedUp, staleAfterFault }

class TicketBackupRecord {
  static const String structuredRecordTypeKey = 'system_record_type';
  static const String noteType = 'backup_record';
  static const String legacyStorageNoteType = 'service_note';

  TicketBackupRecord({
    required this.id,
    required this.ticketId,
    required this.backupPath,
    required this.fileName,
    required this.createdAt,
    this.createdByName,
    this.requestedBy,
    this.requestedSavePath,
    this.requestedAt,
    this.savedAt,
  });

  final String id;
  final String ticketId;
  final String backupPath;
  final String fileName;
  final DateTime? createdAt;
  final String? createdByName;
  final String? requestedBy;
  final String? requestedSavePath;
  final DateTime? requestedAt;
  final DateTime? savedAt;

  static bool isBackupRecordNote(Map<String, dynamic> note) {
    final currentNoteType = note['note_type']?.toString() ?? '';
    if (currentNoteType == noteType) {
      return true;
    }
    if (currentNoteType != legacyStorageNoteType) {
      return false;
    }

    final payload = _parsePayload(note['note']);
    return payload[structuredRecordTypeKey]?.toString() == noteType;
  }

  factory TicketBackupRecord.fromTicketNote(Map<String, dynamic> note) {
    final payload = _parsePayload(note['note']);
    final rawPath = payload['backup_path']?.toString().trim() ?? '';
    final rawFileName = payload['backup_file_name']?.toString().trim() ?? '';
    final rawRequestedBy =
        payload['backup_requested_by']?.toString().trim() ?? '';
    final rawRequestedSavePath =
        payload['backup_requested_save_path']?.toString().trim() ?? '';
    final createdAt = DateTime.tryParse(note['created_at']?.toString() ?? '');
    final requestedAt = DateTime.tryParse(
      payload['backup_requested_at']?.toString() ?? '',
    );
    final savedAt = DateTime.tryParse(
      payload['backup_saved_at']?.toString() ?? '',
    );
    final profile = note['profiles'] as Map<String, dynamic>?;

    return TicketBackupRecord(
      id: note['id']?.toString() ?? '',
      ticketId: note['ticket_id']?.toString() ?? '',
      backupPath: rawPath,
      fileName:
          rawFileName.isNotEmpty ? rawFileName : _extractFileName(rawPath),
      createdAt: createdAt,
      createdByName: profile?['full_name']?.toString(),
      requestedBy: rawRequestedBy.isNotEmpty ? rawRequestedBy : null,
      requestedSavePath:
          rawRequestedSavePath.isNotEmpty ? rawRequestedSavePath : null,
      requestedAt: requestedAt,
      savedAt: savedAt ?? createdAt,
    );
  }

  static Map<String, dynamic> _parsePayload(dynamic rawNote) {
    if (rawNote is Map<String, dynamic>) return rawNote;
    if (rawNote is String && rawNote.trim().isNotEmpty) {
      try {
        final decoded = jsonDecode(rawNote);
        if (decoded is Map<String, dynamic>) {
          return decoded;
        }
      } catch (_) {
        return const <String, dynamic>{};
      }
    }
    return const <String, dynamic>{};
  }

  static String _extractFileName(String path) {
    final normalized = path.replaceAll('\\', '/').trim();
    if (normalized.isEmpty) return 'Yedek.pdf';
    final parts = normalized.split('/');
    return parts.isEmpty ? 'Yedek.pdf' : parts.last;
  }
}

class TicketBackupSnapshot {
  const TicketBackupSnapshot({this.latestBackup, this.latestFaultAt});

  final TicketBackupRecord? latestBackup;
  final DateTime? latestFaultAt;

  bool get hasBackup => latestBackup != null;

  TicketBackupIndicatorState get state {
    if (latestBackup == null) return TicketBackupIndicatorState.none;
    final backupTime = latestBackup?.createdAt;
    if (backupTime != null &&
        latestFaultAt != null &&
        latestFaultAt!.isAfter(backupTime)) {
      return TicketBackupIndicatorState.staleAfterFault;
    }
    return TicketBackupIndicatorState.backedUp;
  }

  bool get needsRefresh => state == TicketBackupIndicatorState.staleAfterFault;

  static TicketBackupSnapshot fromNotes(List<Map<String, dynamic>> notes) {
    TicketBackupRecord? latestBackup;
    DateTime? latestFaultAt;

    for (final note in notes) {
      if (TicketBackupRecord.isBackupRecordNote(note)) {
        final backupRecord = TicketBackupRecord.fromTicketNote(note);
        if (_isLater(backupRecord.createdAt, latestBackup?.createdAt)) {
          latestBackup = backupRecord;
        }
      } else if (TicketFaultRecord.isFaultRecordNote(note)) {
        final faultDate = DateTime.tryParse(
          note['created_at']?.toString() ?? '',
        );
        if (_isLater(faultDate, latestFaultAt)) {
          latestFaultAt = faultDate;
        }
      }
    }

    return TicketBackupSnapshot(
      latestBackup: latestBackup,
      latestFaultAt: latestFaultAt,
    );
  }

  static bool _isLater(DateTime? candidate, DateTime? current) {
    if (candidate == null) return false;
    if (current == null) return true;
    return candidate.isAfter(current);
  }
}
