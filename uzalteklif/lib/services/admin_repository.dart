import 'package:supabase_flutter/supabase_flutter.dart';

class AdminRepository {
  const AdminRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isRemoteReady =>
      _client != null && _client.auth.currentSession != null;

  Future<List<Map<String, dynamic>>> fetchAuditLogs({int limit = 80}) async {
    if (!isRemoteReady) return const [];
    try {
      final rows = await _client!
          .from('audit_logs')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .cast<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<List<Map<String, dynamic>>> fetchQuoteRevisions({
    int limit = 80,
  }) async {
    if (!isRemoteReady) return const [];
    try {
      final rows = await _client!
          .from('quote_revisions')
          .select()
          .order('created_at', ascending: false)
          .limit(limit);
      return rows
          .cast<Map<String, dynamic>>()
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
