import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/inverter_reference_value.dart';

class InverterReferenceService {
  InverterReferenceService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  final SupabaseClient _client;

  Future<List<InverterReferenceValue>> listAll() async {
    final response = await _client
        .from('inverter_reference_values')
        .select()
        .order('device_brand', ascending: true)
        .order('device_model', ascending: true)
        .order('sort_order', ascending: true)
        .order('title', ascending: true);

    return (response as List)
        .map(
          (row) => InverterReferenceValue.fromJson(row as Map<String, dynamic>),
        )
        .toList();
  }

  Future<InverterReferenceValue> create({
    required String deviceBrand,
    required String deviceModel,
    required String title,
    required String registerAddress,
    required String storedValue,
    required String unit,
    required String category,
    required String note,
    required int sortOrder,
  }) async {
    final userId = _client.auth.currentUser?.id;
    if (userId == null) {
      throw Exception('Oturum gerekli');
    }

    final response =
        await _client
            .from('inverter_reference_values')
            .insert({
              'device_brand': deviceBrand.trim(),
              'device_model': deviceModel.trim(),
              'title': title.trim(),
              'register_address': registerAddress.trim(),
              'stored_value': storedValue.trim(),
              'unit': unit.trim(),
              'category': category.trim().isEmpty ? 'general' : category.trim(),
              'note': note.trim(),
              'sort_order': sortOrder,
              'created_by': userId,
            })
            .select()
            .single();

    return InverterReferenceValue.fromJson(response);
  }

  Future<InverterReferenceValue> update({
    required int id,
    required String deviceBrand,
    required String deviceModel,
    required String title,
    required String registerAddress,
    required String storedValue,
    required String unit,
    required String category,
    required String note,
    required int sortOrder,
  }) async {
    final response =
        await _client
            .from('inverter_reference_values')
            .update({
              'device_brand': deviceBrand.trim(),
              'device_model': deviceModel.trim(),
              'title': title.trim(),
              'register_address': registerAddress.trim(),
              'stored_value': storedValue.trim(),
              'unit': unit.trim(),
              'category': category.trim().isEmpty ? 'general' : category.trim(),
              'note': note.trim(),
              'sort_order': sortOrder,
              'updated_at': DateTime.now().toIso8601String(),
            })
            .eq('id', id)
            .select()
            .single();

    return InverterReferenceValue.fromJson(response);
  }

  Future<void> delete(int id) async {
    await _client.from('inverter_reference_values').delete().eq('id', id);
  }
}
