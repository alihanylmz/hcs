import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/discovery_project.dart';

class DiscoveryRepository {
  DiscoveryRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  static final List<DiscoveryProject> _memoryProjects = [];

  bool get isRemoteReady =>
      _client != null && _client.auth.currentSession != null;

  String? get currentUserId => _client?.auth.currentUser?.id;

  Future<List<DiscoveryProject>> fetchAll() async {
    if (!isRemoteReady) {
      return _loadLocal();
    }
    try {
      final rows = await _client!
          .from('discovery_projects')
          .select()
          .order('updated_at', ascending: false);
      final projects = rows
          .cast<Map<String, dynamic>>()
          .map(DiscoveryProject.fromJson)
          .toList(growable: false);
      _memoryProjects
        ..clear()
        ..addAll(projects);
      await _saveLocal();
      return projects;
    } on PostgrestException catch (error) {
      if (_isMissingTable(error)) return _loadLocal();
      rethrow;
    }
  }

  Future<void> save(DiscoveryProject project) async {
    _upsertMemory(project);
    await _saveLocal();
    if (!isRemoteReady) return;

    final row = project.toJson();
    if ((row['created_by'] as String?)?.trim().isEmpty ?? true) {
      row.remove('created_by');
    }
    try {
      await _client!.from('discovery_projects').upsert(row);
    } on PostgrestException catch (error) {
      if (!_isMissingTable(error)) rethrow;
    }
  }

  Future<void> deleteById(String id) async {
    _memoryProjects.removeWhere((project) => project.id == id);
    await _saveLocal();
    if (!isRemoteReady || id.isEmpty) return;
    try {
      await _client!.from('discovery_projects').delete().eq('id', id);
    } on PostgrestException catch (error) {
      if (!_isMissingTable(error)) rethrow;
    }
  }

  List<DiscoveryProject> _sortedMemoryProjects() {
    final result = List<DiscoveryProject>.from(_memoryProjects);
    result.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return result;
  }

  void _upsertMemory(DiscoveryProject project) {
    final index = _memoryProjects.indexWhere((item) => item.id == project.id);
    if (index == -1) {
      _memoryProjects.add(project);
    } else {
      _memoryProjects[index] = project;
    }
  }

  String get _localStorageKey =>
      'discovery_projects_v1_${currentUserId ?? 'local'}';

  Future<List<DiscoveryProject>> _loadLocal() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_localStorageKey);
    if (encoded != null && encoded.trim().isNotEmpty) {
      try {
        final rows = jsonDecode(encoded) as List<dynamic>;
        _memoryProjects
          ..clear()
          ..addAll(
            rows.whereType<Map>().map(
              (row) =>
                  DiscoveryProject.fromJson(Map<String, dynamic>.from(row)),
            ),
          );
      } on FormatException {
        // Bozuk yerel önbellek varsa oturum içindeki sağlam kayıtları koru.
      }
    }
    return _sortedMemoryProjects();
  }

  Future<void> _saveLocal() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _localStorageKey,
      jsonEncode(_memoryProjects.map((project) => project.toJson()).toList()),
    );
  }

  bool _isMissingTable(PostgrestException error) {
    final code = error.code?.toUpperCase();
    return code == 'PGRST205' ||
        code == '42P01' ||
        error.message.toLowerCase().contains('discovery_projects');
  }
}
