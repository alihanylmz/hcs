import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/logging/app_logger.dart';
import '../features/tickets/application/ticket_notification_coordinator.dart';
import '../features/tickets/data/ticket_repository.dart';
import '../models/ticket_backup_record.dart';
import '../models/ticket_daily_report.dart';
import '../models/ticket_fault_record.dart';
import 'fault_record_service.dart';
import 'pdf_export_service.dart';

class TicketService {
  factory TicketService({
    TicketRepository? repository,
    TicketNotificationCoordinator? notificationCoordinator,
    FaultRecordService? faultRecordService,
  }) {
    final repo = repository ?? TicketRepository();
    return TicketService._(
      repository: repo,
      notificationCoordinator:
          notificationCoordinator ??
          TicketNotificationCoordinator(repository: repo),
      faultRecordService: faultRecordService ?? FaultRecordService(),
    );
  }

  TicketService._({
    required TicketRepository repository,
    required TicketNotificationCoordinator notificationCoordinator,
    required FaultRecordService faultRecordService,
  }) : _repository = repository,
       _notificationCoordinator = notificationCoordinator,
       _faultRecordService = faultRecordService;

  static const AppLogger _logger = AppLogger('TicketService');
  final TicketRepository _repository;
  final TicketNotificationCoordinator _notificationCoordinator;
  final FaultRecordService _faultRecordService;

  Future<Map<String, dynamic>?> getTicket(String ticketId) {
    return _repository.getTicket(ticketId);
  }

  Future<void> updateTicket(
    String ticketId,
    Map<String, dynamic> payload,
  ) async {
    final oldTicket = await _repository.getTicket(ticketId);
    await _repository.updateTicket(ticketId, payload);

    if (oldTicket != null) {
      _notificationCoordinator
          .handleTicketUpdated(
            oldTicket: oldTicket,
            payload: payload,
            ticketId: ticketId,
          )
          .catchError((Object error, StackTrace stackTrace) {
            _logger.error(
              'ticket_update_notification_failed',
              data: {'ticketId': ticketId},
              error: error,
              stackTrace: stackTrace,
            );
          });
    }
  }

  Future<List<Map<String, dynamic>>> getNotes(String ticketId) {
    return _repository.getNotes(ticketId);
  }

  Future<List<TicketFaultLinkCandidate>> searchTicketsForFaultLink(
    String query, {
    int limit = 20,
  }) async {
    final rows = await _repository.searchTicketsForFaultLink(
      query,
      limit: limit,
    );
    return rows.map(TicketFaultLinkCandidate.fromJson).toList();
  }

  Future<Map<String, TicketBackupSnapshot>> getBackupStatusForTickets(
    List<String> ticketIds,
  ) async {
    if (ticketIds.isEmpty) return const <String, TicketBackupSnapshot>{};

    final rows = await _repository.getNotesByTypesForTickets(ticketIds, [
      'backup_record',
      'fault_record',
      'service_note',
    ]);

    final grouped = <String, List<Map<String, dynamic>>>{};
    for (final ticketId in ticketIds) {
      grouped[ticketId] = <Map<String, dynamic>>[];
    }

    for (final row in rows) {
      final ticketId = row['ticket_id']?.toString() ?? '';
      grouped.putIfAbsent(ticketId, () => <Map<String, dynamic>>[]).add(row);
    }

    final linkedFaultDates = await _faultRecordService
        .getLatestFaultDatesForTickets(ticketIds);

    return grouped.map((ticketId, notes) {
      final snapshot = TicketBackupSnapshot.fromNotes(notes);
      return MapEntry(
        ticketId,
        TicketBackupSnapshot(
          latestBackup: snapshot.latestBackup,
          latestFaultAt: _latestDate(
            snapshot.latestFaultAt,
            linkedFaultDates[ticketId],
          ),
        ),
      );
    });
  }

  Future<void> addNote(
    String ticketId,
    String note, [
    List<String>? imageUrls,
  ]) async {
    await _repository.addNote(
      ticketId: ticketId,
      note: note,
      noteType: 'service_note',
      imageUrls: imageUrls,
    );

    _notificationCoordinator
        .handleNoteAdded(ticketId: ticketId, isPartnerNote: false)
        .catchError((Object error, StackTrace stackTrace) {
          _logger.error(
            'service_note_notification_failed',
            data: {'ticketId': ticketId},
            error: error,
            stackTrace: stackTrace,
          );
        });
  }

  Future<void> addPartnerNote(
    String ticketId,
    String note, [
    List<String>? imageUrls,
  ]) async {
    await _repository.addNote(
      ticketId: ticketId,
      note: note,
      noteType: 'partner_note',
      imageUrls: imageUrls,
    );

    _notificationCoordinator
        .handleNoteAdded(ticketId: ticketId, isPartnerNote: true)
        .catchError((Object error, StackTrace stackTrace) {
          _logger.error(
            'partner_note_notification_failed',
            data: {'ticketId': ticketId},
            error: error,
            stackTrace: stackTrace,
          );
        });
  }

  Future<void> addDailyReport({
    required String ticketId,
    required TicketDailyReport report,
    List<String>? imageUrls,
  }) async {
    try {
      await _repository.addNote(
        ticketId: ticketId,
        note: report.toStorageText(),
        noteType: TicketDailyReport.noteType,
        imageUrls: imageUrls,
      );
    } on PostgrestException catch (error) {
      if (!_isUnsupportedStructuredNoteType(error)) {
        rethrow;
      }

      await _repository.addNote(
        ticketId: ticketId,
        note: report.toStorageText(),
        noteType: TicketDailyReport.legacyStorageNoteType,
        imageUrls: imageUrls,
      );
    }

    _notificationCoordinator
        .handleNoteAdded(ticketId: ticketId, isPartnerNote: false)
        .catchError((Object error, StackTrace stackTrace) {
          _logger.error(
            'daily_report_notification_failed',
            data: {'ticketId': ticketId},
            error: error,
            stackTrace: stackTrace,
          );
        });
  }

  Future<void> addFaultRecord({
    required String ticketId,
    required String faultCode,
    required String faultTitle,
    required String faultBody,
    String? deviceBrand,
    String? deviceModel,
    String? assigneeId,
    String? assigneeName,
  }) async {
    await _faultRecordService.createFaultRecord(
      linkedTicketId: ticketId,
      faultCode: faultCode,
      title: faultTitle,
      body: faultBody,
      deviceBrand: deviceBrand,
      deviceModel: deviceModel,
      assigneeId: assigneeId,
      assigneeName: assigneeName,
    );
  }

  Future<String?> exportTicketBackup({
    required String ticketId,
    required String suggestedFileName,
    required String requestedBy,
    required String requestedSavePath,
    required DateTime requestedAt,
  }) async {
    final bytes = await PdfExportService.generateSingleTicketPdfBytes(ticketId);
    final safeFileName = _normalizeBackupFileName(suggestedFileName);
    final saveResult = await PdfExportService.savePdf(
      bytes,
      safeFileName.replaceAll(RegExp(r'\.pdf$', caseSensitive: false), ''),
    );

    if (saveResult == null || saveResult.trim().isEmpty) {
      return null;
    }

    final outputFile = _normalizeBackupOutputPath(saveResult.trim());
    final specialResult = _isSpecialBackupResult(outputFile);
    final savedAt = DateTime.now();

    final payload = jsonEncode({
      TicketBackupRecord.structuredRecordTypeKey: TicketBackupRecord.noteType,
      'backup_path': outputFile,
      'backup_file_name':
          specialResult ? safeFileName : _extractFileName(outputFile),
      'backup_requested_by': requestedBy.trim(),
      'backup_requested_save_path': requestedSavePath.trim(),
      'backup_requested_at': requestedAt.toIso8601String(),
      'backup_saved_at': savedAt.toIso8601String(),
    });

    try {
      await _addStructuredRecordNote(
        ticketId: ticketId,
        note: payload,
        primaryNoteType: TicketBackupRecord.noteType,
      );
    } catch (error, stackTrace) {
      _logger.error(
        'backup_record_note_failed',
        data: {'ticketId': ticketId, 'outputFile': outputFile},
        error: error,
        stackTrace: stackTrace,
      );
      throw Exception(
        'Dosya kaydedildi ama yedek kaydi islenemedi. Kayit yolu: $outputFile',
      );
    }

    return outputFile;
  }

  Future<void> updateNote(int noteId, String note) {
    return _repository.updateNote(noteId, note);
  }

  Future<void> _addStructuredRecordNote({
    required String ticketId,
    required String note,
    required String primaryNoteType,
  }) async {
    try {
      await _repository.addNote(
        ticketId: ticketId,
        note: note,
        noteType: primaryNoteType,
      );
    } on PostgrestException catch (error) {
      if (!_isUnsupportedStructuredNoteType(error)) {
        rethrow;
      }

      await _repository.addNote(
        ticketId: ticketId,
        note: note,
        noteType: 'service_note',
      );
    }
  }

  bool _isUnsupportedStructuredNoteType(PostgrestException error) {
    final message =
        [
          error.message,
          error.details,
          error.hint,
          error.code,
        ].whereType<String>().join(' ').toLowerCase();
    return message.contains('check_note_type') ||
        (message.contains('note_type') && message.contains('check')) ||
        message.contains('violates check constraint');
  }

  Future<Uint8List?> compressImage(Uint8List bytes) {
    return _repository.compressImage(bytes);
  }

  Future<List<String>> uploadImages(String ticketId, List<PlatformFile> files) {
    return _repository.uploadImages(ticketId, files);
  }

  Future<String?> uploadFile(String ticketId, PlatformFile file) {
    return _repository.uploadFile(ticketId, file);
  }

  String _normalizeBackupFileName(String rawName) {
    final trimmed = rawName.trim();
    final sanitized = trimmed.replaceAll(RegExp(r'[<>:"/\\|?*]+'), '_');
    if (sanitized.toLowerCase().endsWith('.pdf')) {
      return sanitized;
    }
    return '$sanitized.pdf';
  }

  String _extractFileName(String path) {
    final normalized = path.replaceAll('\\', '/');
    final segments = normalized.split('/');
    return segments.isEmpty ? 'Yedek.pdf' : segments.last;
  }

  String _normalizeBackupOutputPath(String rawResult) {
    var normalized = rawResult.trim();
    const desktopPrefix = 'Dosya kaydedildi:';
    if (normalized.startsWith(desktopPrefix)) {
      normalized = normalized.substring(desktopPrefix.length).trim();
    }

    if (_isSpecialBackupResult(normalized)) {
      return normalized;
    }

    if (!normalized.toLowerCase().endsWith('.pdf')) {
      normalized = '$normalized.pdf';
    }

    return normalized;
  }

  bool _isSpecialBackupResult(String value) {
    return value.startsWith('Dosya ');
  }

  DateTime? _latestDate(DateTime? left, DateTime? right) {
    if (left == null) return right;
    if (right == null) return left;
    return left.isAfter(right) ? left : right;
  }
}
