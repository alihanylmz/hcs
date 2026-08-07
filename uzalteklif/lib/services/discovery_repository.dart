import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/discovery_templates.dart';
import '../models/discovery_project.dart';

class DiscoveryRepository {
  DiscoveryRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  static final List<DiscoveryProject> _memoryProjects = [];
  static final List<DiscoveryDeviceTemplate> _memoryDeviceTemplates = [];

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

  Future<List<DiscoveryDeviceTemplate>> fetchDeviceTemplates() async {
    final localTemplates = await _loadLocalDeviceTemplates();
    if (!isRemoteReady) return localTemplates;
    try {
      final rows = await _client!
          .from('discovery_device_templates')
          .select()
          .order('name');
      final templates = rows
          .cast<Map<String, dynamic>>()
          .map(DiscoveryDeviceTemplate.fromJson)
          .where((template) => template.key.isNotEmpty)
          .toList(growable: false);
      final merged = {
        for (final template in localTemplates) template.key: template,
        for (final template in templates) template.key: template,
      };
      _memoryDeviceTemplates
        ..clear()
        ..addAll(merged.values);
      await _saveLocalDeviceTemplates();
      return List.unmodifiable(_memoryDeviceTemplates);
    } on PostgrestException catch (error) {
      if (_isMissingDeviceTemplateTable(error)) {
        return _loadLocalDeviceTemplates();
      }
      rethrow;
    }
  }

  Future<void> saveDeviceTemplate(DiscoveryDeviceTemplate template) async {
    final index = _memoryDeviceTemplates.indexWhere(
      (item) => item.key == template.key,
    );
    if (index == -1) {
      _memoryDeviceTemplates.add(template);
    } else {
      _memoryDeviceTemplates[index] = template;
    }
    await _saveLocalDeviceTemplates();
    if (!isRemoteReady) return;
    final row = {
      ...template.toJson(),
      'created_by': currentUserId,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };
    try {
      await _client!.from('discovery_device_templates').upsert(row);
    } on PostgrestException catch (error) {
      if (!_isMissingDeviceTemplateTable(error)) rethrow;
    }
  }

  Future<void> deleteDeviceTemplate(String id) async {
    _memoryDeviceTemplates.removeWhere((template) => template.key == id);
    await _saveLocalDeviceTemplates();
    if (!isRemoteReady || id.isEmpty) return;
    try {
      await _client!.from('discovery_device_templates').delete().eq('id', id);
    } on PostgrestException catch (error) {
      if (!_isMissingDeviceTemplateTable(error)) rethrow;
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

  String get _localDeviceTemplateStorageKey =>
      'discovery_device_templates_v1_${currentUserId ?? 'local'}';

  Future<List<DiscoveryDeviceTemplate>> _loadLocalDeviceTemplates() async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_localDeviceTemplateStorageKey);
    if (encoded != null && encoded.trim().isNotEmpty) {
      try {
        final rows = jsonDecode(encoded) as List<dynamic>;
        _memoryDeviceTemplates
          ..clear()
          ..addAll(
            rows.whereType<Map>().map(
              (row) => DiscoveryDeviceTemplate.fromJson(
                Map<String, dynamic>.from(row),
              ),
            ),
          );
      } on FormatException {
        // Bozuk yerel şablon kaydı varsa oturumdaki sağlam veriyi koru.
      }
    }
    return List.unmodifiable(_memoryDeviceTemplates);
  }

  Future<void> _saveLocalDeviceTemplates() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(
      _localDeviceTemplateStorageKey,
      jsonEncode(
        _memoryDeviceTemplates
            .map((template) => template.toJson())
            .toList(growable: false),
      ),
    );
  }

  bool _isMissingTable(PostgrestException error) {
    final code = error.code?.toUpperCase();
    return code == 'PGRST205' ||
        code == '42P01' ||
        error.message.toLowerCase().contains('discovery_projects');
  }

  bool _isMissingDeviceTemplateTable(PostgrestException error) {
    final code = error.code?.toUpperCase();
    return code == 'PGRST205' ||
        code == '42P01' ||
        error.message.toLowerCase().contains('discovery_device_templates');
  }
}
