import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/cari_account.dart';

class CariRepository {
  CariRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isRemoteReady =>
      _client != null && _client.auth.currentSession != null;

  Future<List<CariAccount>> fetchAll() async {
    if (!isRemoteReady) return const [];
    final client = _client!;
    final rows = await client
        .from('customer_accounts')
        .select()
        .order('company_name', ascending: true);
    return rows
        .cast<Map<String, dynamic>>()
        .map(CariAccount.fromJson)
        .toList(growable: false);
  }

  Future<void> save(CariAccount cari) async {
    if (!isRemoteReady) return;
    final row = cari.toJson();
    if ((row['created_by'] as String?)?.trim().isEmpty ?? true) {
      row.remove('created_by');
    }
    await _client!.from('customer_accounts').upsert(row);
  }

  Future<void> deleteById(String id) async {
    if (!isRemoteReady || id.isEmpty) return;
    await _client!.from('customer_accounts').delete().eq('id', id);
  }
}
