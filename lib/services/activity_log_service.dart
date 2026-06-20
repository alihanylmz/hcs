import 'package:supabase_flutter/supabase_flutter.dart';

class ActivityLogService {
  ActivityLogService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

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
    await _client.from('activity_logs').insert({
      'actor_id': user?.id,
      'actor_name': _displayName(user),
      'action': 'Manuel not yazdı',
      'action_key': 'manual_note',
      'work_code': workCode?.trim() ?? '',
      'note': cleanNote,
      'source': 'manual',
      'created_year': DateTime.now().toUtc().year,
    });
  }

  String _displayName(User? user) {
    if (user == null) return '';
    final metadata = user.userMetadata ?? const <String, dynamic>{};
    final name = '${metadata['full_name'] ?? metadata['name'] ?? ''}'.trim();
    if (name.isNotEmpty) return name;
    return user.email ?? '';
  }
}
