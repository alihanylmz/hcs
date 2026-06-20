import 'package:supabase_flutter/supabase_flutter.dart';

import 'notification_service.dart';

class ActivityLogService {
  ActivityLogService({
    SupabaseClient? client,
    NotificationService? notificationService,
  }) : _client = client ?? Supabase.instance.client,
       _notificationService = notificationService ?? NotificationService();

  final SupabaseClient _client;
  final NotificationService _notificationService;

  Future<List<Map<String, dynamic>>> fetchLogs({
    String? userId,
    int limit = 200,
  }) async {
    var query = _client.from('activity_logs').select();
    if (userId != null && userId.trim().isNotEmpty) {
      query = query.eq('actor_id', userId.trim());
    }
    final rows = await query.order('created_at', ascending: false).limit(limit);
    return rows.cast<Map<String, dynamic>>().toList(growable: false);
  }

  Future<List<Map<String, dynamic>>> fetchLogsForJob({
    required String jobId,
    String? workCode,
    int limit = 120,
  }) async {
    final rows = await _client
        .from('activity_logs')
        .select()
        .eq('job_id', jobId)
        .order('created_at', ascending: false)
        .limit(limit);

    final logs = rows.cast<Map<String, dynamic>>().toList(growable: false);
    if (logs.isNotEmpty || (workCode ?? '').trim().isEmpty) return logs;

    final fallbackRows = await _client
        .from('activity_logs')
        .select()
        .eq('work_code', workCode!.trim())
        .order('created_at', ascending: false)
        .limit(limit);
    return fallbackRows.cast<Map<String, dynamic>>().toList(growable: false);
  }

  Future<void> addManualNote({required String note, String? workCode}) async {
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) return;

    final user = _client.auth.currentUser;
    final actorName = _displayName(user);
    final cleanWorkCode = workCode?.trim() ?? '';

    await _client.from('activity_logs').insert({
      'actor_id': user?.id,
      'user_id': user?.id,
      'actor_name': actorName,
      'action': 'Manuel not yazdi',
      'action_key': 'manual_note',
      'activity_type': 'manual_note',
      'work_code': cleanWorkCode,
      'message': cleanNote,
      'note': cleanNote,
      'source': 'manual',
      'is_manual_note': true,
      'created_year': DateTime.now().toUtc().year,
    });

    await _notifyManualNoteToEveryone(
      actorName: actorName,
      note: cleanNote,
      workCode: cleanWorkCode,
    );
  }

  Future<void> addJobManualNote({
    required String jobId,
    required String note,
    String? workCode,
    String? jobType,
  }) async {
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) return;

    final user = _client.auth.currentUser;
    final actorName = _displayName(user);
    final cleanWorkCode = workCode?.trim() ?? '';

    await _client.from('activity_logs').insert({
      'job_id': jobId,
      'actor_id': user?.id,
      'user_id': user?.id,
      'actor_name': actorName,
      'action': 'Manuel not yazdi',
      'action_key': 'manual_note',
      'activity_type': 'manual_note',
      'work_code': cleanWorkCode,
      'message': cleanNote,
      'note': cleanNote,
      'source': 'manual',
      'is_manual_note': true,
      'metadata': {'ticket_id': jobId, 'job_type': jobType},
      'created_year': DateTime.now().toUtc().year,
    });

    await _notifyManualNoteToEveryone(
      actorName: actorName,
      note: cleanNote,
      workCode: cleanWorkCode,
    );
  }

  Future<void> addJobActivity({
    required String jobId,
    required String activityType,
    required String message,
    String? workCode,
    String? jobType,
  }) async {
    final cleanMessage = message.trim();
    if (cleanMessage.isEmpty) return;

    final user = _client.auth.currentUser;
    final actorName = _displayName(user);

    await _client.from('activity_logs').insert({
      'job_id': jobId,
      'actor_id': user?.id,
      'user_id': user?.id,
      'actor_name': actorName,
      'action': cleanMessage,
      'action_key': activityType,
      'activity_type': activityType,
      'work_code': workCode?.trim() ?? '',
      'message': cleanMessage,
      'note': '',
      'source': 'auto',
      'is_manual_note': false,
      'metadata': {'ticket_id': jobId, 'job_type': jobType},
      'created_year': DateTime.now().toUtc().year,
    });
  }

  Future<void> _notifyManualNoteToEveryone({
    required String actorName,
    required String note,
    required String workCode,
  }) async {
    final rows = await _client.from('profiles').select('id');
    final userIds = rows
        .cast<Map<String, dynamic>>()
        .map((row) => '${row['id'] ?? ''}'.trim())
        .where((id) => id.isNotEmpty)
        .toSet()
        .toList(growable: false);
    if (userIds.isEmpty) return;

    final author = actorName.trim().isEmpty ? 'Bir kullanici' : actorName;
    final notePreview =
        note.length > 120 ? '${note.substring(0, 120)}...' : note;
    final message =
        workCode.isEmpty
            ? '$author manuel not yazdi: $notePreview'
            : '$author $workCode icin manuel not yazdi: $notePreview';

    await _notificationService.sendNotificationToExternalUsers(
      externalUserIds: userIds,
      title: 'Yeni manuel not',
      message: message,
      data: {
        'type': 'activity_manual_note',
        'route': 'activity_logs',
        'work_code': workCode,
      },
    );
  }

  String _displayName(User? user) {
    if (user == null) return '';
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final name = '${metadata['full_name'] ?? metadata['name'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
    return user.email ?? '';
  }
}
