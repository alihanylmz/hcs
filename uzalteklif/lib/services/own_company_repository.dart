import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/own_company.dart';

class OwnCompanyRepository {
  const OwnCompanyRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  bool get isRemoteReady =>
      _client != null && _client.auth.currentSession != null;

  Future<List<OwnCompany>> fetchAll() async {
    if (!isRemoteReady) return [OwnCompany.fallback()];
    final rows = await _client!
        .from('own_companies')
        .select()
        .order('is_default', ascending: false)
        .order('name', ascending: true);
    final companies = rows
        .cast<Map<String, dynamic>>()
        .map(OwnCompany.fromJson)
        .toList(growable: false);
    return companies.isEmpty ? [OwnCompany.fallback()] : companies;
  }

  Future<void> save(OwnCompany company) async {
    if (!isRemoteReady) return;
    if (company.isDefault) {
      await _client!
          .from('own_companies')
          .update({'is_default': false})
          .neq('id', company.id);
    }
    await _client!.from('own_companies').upsert(company.toJson());
  }

  Future<void> setDefault(String id) async {
    if (!isRemoteReady || id.isEmpty) return;
    await _client!
        .from('own_companies')
        .update({'is_default': false})
        .neq('id', id);
    await _client
        .from('own_companies')
        .update({'is_default': true})
        .eq('id', id);
  }

  Future<void> deleteById(String id) async {
    if (!isRemoteReady || id.isEmpty) return;
    await _client!.from('own_companies').delete().eq('id', id);
  }
}
