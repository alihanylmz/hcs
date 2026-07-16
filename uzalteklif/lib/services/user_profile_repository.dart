import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_quote_profile.dart';

class UserProfileRepository {
  UserProfileRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isRemoteReady =>
      _client != null && _client.auth.currentSession != null;

  Future<UserQuoteProfile?> fetchMine() async {
    if (!isRemoteReady) return null;
    final client = _client!;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await client
          .from('user_profiles')
          .select()
          .eq('user_id', uid)
          .maybeSingle();
      if (row == null) return null;
      return UserQuoteProfile.fromRow(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  Future<void> upsert(UserQuoteProfile profile) async {
    if (!isRemoteReady) return;
    await _client!.from('user_profiles').upsert(profile.toRow());
  }

  Future<List<UserQuoteProfile>> fetchAll() async {
    if (!isRemoteReady) return const [];
    try {
      final rows = await _client!
          .from('user_profiles')
          .select()
          .order('prepared_by_name', ascending: true);
      return rows
          .cast<Map<String, dynamic>>()
          .map(UserQuoteProfile.fromRow)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<void> updateRole({
    required String userId,
    required String role,
  }) async {
    if (!isRemoteReady || userId.isEmpty) return;
    await _client!
        .from('user_profiles')
        .update({'role': UserQuoteProfile.normalizeRole(role)})
        .eq('user_id', userId);
  }
}
