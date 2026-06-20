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

  Future<void> addManualNote({required String note, String? workCode}) async {
    final cleanNote = note.trim();
    if (cleanNote.isEmpty) return;

    final user = _client.auth.currentUser;
    final actorName = _displayName(user);
    final cleanWorkCode = workCode?.trim() ?? '';

    await _client.from('activity_logs').insert({
      'actor_id': user?.id,
      'actor_name': actorName,
      'action': 'Manuel not yazdı',
      'action_key': 'manual_note',
      'work_code': cleanWorkCode,
      'note': cleanNote,
      'source': 'manual',
      'created_year': DateTime.now().toUtc().year,
    });

    await _notifyManualNoteToEveryone(
      actorName: actorName,
      note: cleanNote,
      workCode: cleanWorkCode,
    );
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

    final author = actorName.trim().isEmpty ? 'Bir kullanıcı' : actorName;
    final notePreview =
        note.length > 120 ? '${note.substring(0, 120)}...' : note;
    final message =
        workCode.isEmpty
            ? '$author manuel not yazdı: $notePreview'
            : '$author $workCode için manuel not yazdı: $notePreview';

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
