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

  Future<CariAccount?> fetchById(String id) async {
    if (!isRemoteReady || id.trim().isEmpty) return null;
    final client = _client!;
    final row = await client
        .from('customer_accounts')
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return CariAccount.fromJson(row);
  }

  Future<void> save(CariAccount cari) async {
    if (!isRemoteReady) return;
    final row = cari.toJson();
    if ((row['created_by'] as String?)?.trim().isEmpty ?? true) {
      row.remove('created_by');
    }
    await _client!.from('customer_accounts').upsert(row);
  }

  /// Eğer verilen cari hesaba [contactName] adlı yetkili eklenmemişse otomatik olarak ekler ve günceller.
  /// Güncellenmiş [CariAccount] nesnesini döndürür.
  Future<CariAccount> ensureContactExists(
    CariAccount cari,
    String contactName, {
    String title = '',
    String phone = '',
    String email = '',
  }) async {
    final cleanName = contactName.trim();
    if (cleanName.isEmpty) return cari;

    if (cari.hasContact(cleanName)) {
      return cari;
    }

    final newContact = CariContact(
      name: cleanName,
      title: title.trim(),
      phone: phone.trim(),
      email: email.trim(),
      isPrimary: cari.contacts.isEmpty,
    );

    final updatedContacts = [...cari.contacts, newContact];
    final updatedCari = cari.copyWith(
      contacts: updatedContacts,
      contactName: cari.contactName.isEmpty ? cleanName : cari.contactName,
      contactTitle: cari.contactTitle.isEmpty ? title : cari.contactTitle,
      phone: cari.phone.isEmpty ? phone : cari.phone,
      email: cari.email.isEmpty ? email : cari.email,
      updatedAt: DateTime.now().toUtc(),
    );

    await save(updatedCari);
    return updatedCari;
  }

  Future<void> deleteById(String id) async {
    if (!isRemoteReady || id.isEmpty) return;
    await _client!.from('customer_accounts').delete().eq('id', id);
  }
}
