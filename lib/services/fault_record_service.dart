import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/fault_record.dart';
import '../models/fault_record_note.dart';
import '../models/user_profile.dart';
import 'user_service.dart';

class FaultRecordService {
  FaultRecordService({SupabaseClient? client, UserService? userService})
    : _client = client ?? Supabase.instance.client,
      _userService = userService ?? UserService(client: client);

  final SupabaseClient _client;
  final UserService _userService;
  bool? _supportsFaultRecordsCache;
  bool? _supportsFaultRecordNotesCache;

  Future<String> createFaultRecord({
    required String faultCode,
    required String title,
    required String body,
    String? deviceBrand,
    String? deviceModel,
    String? linkedTicketId,
    String? assigneeId,
    String? assigneeName,
  }) async {
    final hasFaultRecordsSupport = await supportsFaultRecords();
    if (!hasFaultRecordsSupport) {
      throw _missingFaultSchemaException();
    }

    final profile = await _userService.getCurrentUserProfile();
    final user = _client.auth.currentUser;

    final payload = <String, dynamic>{
      'fault_code': _sanitizeOrFallback(faultCode, fallback: '-'),
      'title': _sanitizeOrFallback(title, fallback: 'Ariza kaydi'),
      'body': _sanitizeOrFallback(body, fallback: 'Aciklama girilmedi.'),
      'status': FaultRecordStatus.open,
      'device_brand': _nullableText(deviceBrand),
      'device_model': _nullableText(deviceModel),
      'linked_ticket_id': _normalizeTicketId(linkedTicketId),
      'assignee_id': _nullableText(assigneeId),
      'assignee_name': _nullableText(assigneeName),
      'created_by': user?.id,
      'created_by_name': _resolveCreatorName(profile, user),
    };

    final inserted =
        await _client.from('fault_records').insert(payload).select().single();
    return FaultRecord.fromJson(Map<String, dynamic>.from(inserted)).id;
  }

  Future<FaultRecord> getFaultRecord(String faultRecordId) async {
    final hasFaultRecordsSupport = await supportsFaultRecords();
    if (!hasFaultRecordsSupport) {
      throw _missingFaultSchemaException();
    }

    final row =
        await _client
            .from('fault_records')
            .select()
            .eq('id', faultRecordId)
            .single();
    return FaultRecord.fromJson(Map<String, dynamic>.from(row));
  }

  Future<List<FaultRecordNote>> getFaultNotes(String faultRecordId) async {
    final hasFaultRecordNotesSupport = await supportsFaultRecordNotes();
    if (!hasFaultRecordNotesSupport) {
      return const <FaultRecordNote>[];
    }

    final rows = await _client
        .from('fault_record_notes')
        .select()
        .eq('fault_record_id', faultRecordId)
        .order('created_at', ascending: true);
    return List<Map<String, dynamic>>.from(
      rows,
    ).map(FaultRecordNote.fromJson).toList();
  }

  Future<void> addFaultNote(
    String faultRecordId,
    String note, {
    String noteType = 'note',
  }) async {
    final trimmedNote = note.trim();
    if (trimmedNote.isEmpty) return;

    final hasFaultRecordNotesSupport = await supportsFaultRecordNotes();
    if (!hasFaultRecordNotesSupport) {
      throw _missingFaultSchemaException();
    }

    final profile = await _userService.getCurrentUserProfile();
    final user = _client.auth.currentUser;

    await _client.from('fault_record_notes').insert({
      'fault_record_id': faultRecordId,
      'note': trimmedNote,
      'note_type': _sanitizeOrFallback(noteType, fallback: 'note'),
      'user_id': user?.id,
      'user_name': _resolveCreatorName(profile, user),
      'user_role': profile?.role,
    });
  }

  Future<List<FaultRecord>> getLinkedFaultsForTicket(String ticketId) async {
    final resolvedTicketId = _normalizeTicketId(ticketId);
    if (resolvedTicketId == null) return const <FaultRecord>[];

    final hasFaultRecordsSupport = await supportsFaultRecords();
    if (!hasFaultRecordsSupport) {
      return const <FaultRecord>[];
    }

    final rows = await _client
        .from('fault_records')
        .select()
        .eq('linked_ticket_id', resolvedTicketId)
        .order('created_at', ascending: false);

    return List<Map<String, dynamic>>.from(
      rows,
    ).map(FaultRecord.fromJson).toList();
  }

  Future<Map<String, FaultTicketLinkSummary>> getTicketLinkSummaries(
    List<String> ticketIds,
  ) async {
    if (ticketIds.isEmpty) return const <String, FaultTicketLinkSummary>{};

    final hasFaultRecordsSupport = await supportsFaultRecords();
    if (!hasFaultRecordsSupport) {
      return const <String, FaultTicketLinkSummary>{};
    }

    final resolvedIds =
        ticketIds
            .map(_normalizeTicketId)
            .whereType<String>()
            .toList();
    if (resolvedIds.isEmpty) {
      return const <String, FaultTicketLinkSummary>{};
    }

    final rows = await _client
        .from('fault_records')
        .select('id, linked_ticket_id, created_at')
        .inFilter('linked_ticket_id', resolvedIds)
        .order('created_at', ascending: false);

    final grouped = <String, FaultTicketLinkSummary>{};
    for (final row in List<Map<String, dynamic>>.from(rows)) {
      final ticketId = row['linked_ticket_id']?.toString();
      if (ticketId == null || ticketId.trim().isEmpty) {
        continue;
      }

      final existing = grouped[ticketId];
      final createdAt = _parseDate(row['created_at']);
      if (existing == null) {
        grouped[ticketId] = FaultTicketLinkSummary(
          ticketId: ticketId,
          faultCount: 1,
          latestFaultId: row['id']?.toString(),
          latestFaultAt: createdAt,
        );
        continue;
      }

      grouped[ticketId] = FaultTicketLinkSummary(
        ticketId: ticketId,
        faultCount: existing.faultCount + 1,
        latestFaultId: existing.latestFaultId,
        latestFaultAt: existing.latestFaultAt,
      );
    }

    return grouped;
  }

  Future<Map<String, DateTime>> getLatestFaultDatesForTickets(
    List<String> ticketIds,
  ) async {
    final summaries = await getTicketLinkSummaries(ticketIds);
    return summaries.map(
      (ticketId, summary) =>
          MapEntry(ticketId, summary.latestFaultAt ?? DateTime(1970)),
    )..removeWhere((_, value) => value.year == 1970);
  }

  Future<List<LinkedFaultNoteEntry>> getLinkedFaultNoteEntries(
    String ticketId,
  ) async {
    final hasFaultRecordNotesSupport = await supportsFaultRecordNotes();
    if (!hasFaultRecordNotesSupport) {
      return const <LinkedFaultNoteEntry>[];
    }

    final records = await getLinkedFaultsForTicket(ticketId);
    if (records.isEmpty) return const <LinkedFaultNoteEntry>[];

    final recordMap = <String, FaultRecord>{
      for (final record in records) record.id: record,
    };
    final faultIds = recordMap.keys.toList();

    final rows = await _client
        .from('fault_record_notes')
        .select()
        .inFilter('fault_record_id', faultIds)
        .order('created_at', ascending: true);

    return List<Map<String, dynamic>>.from(rows).map((row) {
      final note = FaultRecordNote.fromJson(row);
      final record = recordMap[note.faultRecordId];
      return LinkedFaultNoteEntry(
        faultRecordId: note.faultRecordId,
        faultCode: record?.faultCode ?? '-',
        faultTitle: record?.title ?? 'Ariza kaydi',
        note: note.note,
        noteType: note.noteType,
        userName: note.userName,
        userRole: note.userRole,
        createdAt: note.createdAt,
      );
    }).toList();
  }

  Future<bool> supportsFaultRecords() async {
    if (_supportsFaultRecordsCache != null) {
      return _supportsFaultRecordsCache!;
    }

    try {
      await _client.from('fault_records').select('id').limit(1);
      _supportsFaultRecordsCache = true;
      return true;
    } on PostgrestException catch (error) {
      if (_isMissingTable(error, 'fault_records')) {
        _supportsFaultRecordsCache = false;
        return false;
      }
      rethrow;
    }
  }

  Future<bool> supportsFaultRecordNotes() async {
    if (_supportsFaultRecordNotesCache != null) {
      return _supportsFaultRecordNotesCache!;
    }

    try {
      await _client.from('fault_record_notes').select('id').limit(1);
      _supportsFaultRecordNotesCache = true;
      return true;
    } on PostgrestException catch (error) {
      if (_isMissingTable(error, 'fault_record_notes')) {
        _supportsFaultRecordNotesCache = false;
        return false;
      }
      rethrow;
    }
  }

  String? _normalizeTicketId(String? ticketId) {
    final raw = ticketId?.trim() ?? '';
    if (raw.isEmpty) return null;
    return raw;
  }

  String _resolveCreatorName(UserProfile? profile, User? user) {
    final fromProfile = profile?.displayName.trim() ?? '';
    if (fromProfile.isNotEmpty) return fromProfile;
    final fromUser = user?.email?.trim() ?? '';
    if (fromUser.isNotEmpty) return fromUser;
    return 'Bilinmeyen kullanici';
  }

  String _sanitizeOrFallback(String value, {required String fallback}) {
    final trimmed = value.trim();
    return trimmed.isEmpty ? fallback : trimmed;
  }

  String? _nullableText(String? value) {
    final trimmed = value?.trim() ?? '';
    return trimmed.isEmpty ? null : trimmed;
  }

  DateTime? _parseDate(dynamic value) {
    final raw = value?.toString().trim() ?? '';
    if (raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  bool _isMissingTable(PostgrestException error, String tableName) {
    final message = [
      error.code,
      error.message,
      error.details,
      error.hint,
    ].whereType<String>().join(' ').toLowerCase();

    return message.contains(tableName.toLowerCase()) &&
        (message.contains('schema cache') ||
            message.contains('relation') ||
            error.code == '42P01' ||
            error.code == 'PGRST205');
  }

  Exception _missingFaultSchemaException() {
    return Exception(
      'Ariza kayit tablolari Supabase tarafinda henuz kurulmamis. '
      '20260331_create_fault_records.sql migration dosyasini calistirman gerekiyor.',
    );
  }
}
