import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/control_hardware_defaults.dart';
import '../models/control_hardware.dart';

class ControlHardwareRepository {
  ControlHardwareRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  static final List<ControlHardware> _memoryItems = [];

  bool get isRemoteReady =>
      _client != null && _client.auth.currentSession != null;

  String? get currentUserId => _client?.auth.currentUser?.id;

  Future<List<ControlHardware>> fetchAll() async {
    if (!isRemoteReady) {
      return _loadLocal();
    }
    try {
      final rows = await _client!
          .from('control_hardware_catalog')
          .select()
          .order('brand')
          .order('model');
      final items = rows
          .cast<Map<String, dynamic>>()
          .map(ControlHardware.fromJson)
          .toList(growable: false);
      if (items.isEmpty) {
        final localItems = await _loadLocal();
        for (final item in localItems) {
          await _saveRemote(item);
        }
        return localItems;
      }
      _memoryItems
        ..clear()
        ..addAll(items);
      await _saveLocal();
      return _sortedMemoryItems();
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return _loadLocal();
      rethrow;
    }
  }

  Future<void> save(ControlHardware item) async {
    _upsertMemory(item);
    await _saveLocal();
    if (!isRemoteReady) return;
    try {
      await _saveRemote(item);
    } on PostgrestException catch (error) {
      if (!_isMissingTable(error)) rethrow;
    }
  }

  Future<void> deleteById(String id) async {
    _memoryItems.removeWhere((item) => item.id == id);
    await _saveLocal();
    if (!isRemoteReady || id.isEmpty) return;
    try {
      await _client!.from('control_hardware_catalog').delete().eq('id', id);
    } on PostgrestException catch (error) {
      if (!_isMissingTable(error)) rethrow;
    }
  }

  Future<void> _saveRemote(ControlHardware item) async {
    final row = item.toJson();
    if ((row['created_by'] as String?)?.trim().isEmpty ?? true) {
      row.remove('created_by');
    }
    await _client!.from('control_hardware_catalog').upsert(row);
  }

  List<ControlHardware> _seedDefaults() {
    _memoryItems
      ..clear()
      ..addAll(
        ControlHardwareDefaults.values.map(
          (item) => item.copyWith(createdBy: currentUserId),
        ),
      );
    return _sortedMemoryItems();
  }

  List<ControlHardware> _sortedMemoryItems() {
    final result = List<ControlHardware>.from(_memoryItems);
    result.sort((left, right) {
      final brandResult = left.brand.toLowerCase().compareTo(
        right.brand.toLowerCase(),
      );
      if (brandResult != 0) return brandResult;
      return left.model.toLowerCase().compareTo(right.model.toLowerCase());
    });
    return result;
  }

  void _upsertMemory(ControlHardware item) {
    final index = _memoryItems.indexWhere((current) => current.id == item.id);
    if (index == -1) {
      _memoryItems.add(item);
    } else {
      _memoryItems[index] = item;
    }
  }

  String get _localStorageKey =>
      'control_hardware_catalog_v1_${currentUserId ?? 'local'}';

  Future<List<ControlHardware>> _loadLocal() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_localStorageKey);
    if (encoded != null && encoded.trim().isNotEmpty) {
      try {
        final rows = jsonDecode(encoded) as List<dynamic>;
        _memoryItems
          ..clear()
          ..addAll(
            rows.whereType<Map>().map(
              (row) => ControlHardware.fromJson(Map<String, dynamic>.from(row)),
            ),
          );
      } on FormatException {
        // Bozuk yerel önbellek yerine başlangıç kayıtları kullanılır.
      }
    }
    if (encoded == null) {
      final defaults = _seedDefaults();
      await _saveLocal();
      return defaults;
    }
    return _sortedMemoryItems();
  }

  Future<void> _saveLocal() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _localStorageKey,
      jsonEncode(_memoryItems.map((item) => item.toJson()).toList()),
    );
  }

  bool _isMissingTable(PostgrestException error) {
    final code = error.code?.toUpperCase();
    return code == 'PGRST205' ||
        code == '42P01' ||
        error.message.toLowerCase().contains('control_hardware_catalog');
  }
}
