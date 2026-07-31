import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/user_quote_profile.dart';

class UserProfileRepository {
  UserProfileRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isRemoteReady =>
      _client != null && _client.auth.currentSession != null;

  Future<bool> canAccessQuoteApp() async {
    if (!isRemoteReady) return true;
    final uid = _client!.auth.currentUser?.id;
    if (uid == null) return false;
    final row = await _client
        .from('user_app_access')
        .select('is_active')
        .eq('user_id', uid)
        .eq('app_code', 'teklif')
        .maybeSingle();
    return row?['is_active'] == true;
  }

  Future<UserQuoteProfile?> fetchMine() async {
    if (!isRemoteReady) return null;
    final client = _client!;
    final uid = client.auth.currentUser?.id;
    if (uid == null) return null;
    try {
      final row = await client
          .from('quote_user_profiles')
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
    final client = _client!;
    await client
        .from('user_quote_settings')
        .upsert(profile.toUnifiedSettingsRow());
    await client
        .from('profiles')
        .update({'full_name': profile.preparedByName})
        .eq('id', profile.userId);
  }

  Future<List<UserQuoteProfile>> fetchAll() async {
    if (!isRemoteReady) return const [];
    try {
      final rows = await _client!
          .from('quote_user_profiles')
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
    final normalized = UserQuoteProfile.normalizeRole(role);
    await _client!
        .from('user_app_access')
        .update({'app_role': normalized})
        .eq('user_id', userId)
        .eq('app_code', 'teklif');
  }
}
