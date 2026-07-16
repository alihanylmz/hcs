import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/price_adjustment_rule.dart';

class PriceAdjustmentRuleRepository {
  const PriceAdjustmentRuleRepository({SupabaseClient? client})
    : _client = client;

  final SupabaseClient? _client;

  static final List<PriceAdjustmentRule> _memoryRules = [
    PriceAdjustmentRule(
      id: 'rule-honeywell-10',
      name: 'Honeywell marka zammı',
      scope: PriceAdjustmentScope.brand,
      brand: 'Honeywell',
      percentage: 10,
      isActive: true,
      updatedAt: DateTime.now(),
    ),
    PriceAdjustmentRule(
      id: 'rule-sensor-20',
      name: 'Sensör grubu zammı',
      scope: PriceAdjustmentScope.category,
      category: 'Sensor',
      percentage: 20,
      isActive: true,
      updatedAt: DateTime.now(),
    ),
  ];

  bool get isRemoteReady =>
      _client != null && _client.auth.currentSession != null;

  Future<List<PriceAdjustmentRule>> fetchRules() async {
    if (!isRemoteReady) return _sortedMemoryRules();

    final rows = await _client!
        .from('price_adjustment_rules')
        .select()
        .order('updated_at', ascending: false);
    return rows
        .cast<Map<String, dynamic>>()
        .map(PriceAdjustmentRule.fromJson)
        .toList(growable: false);
  }

  Future<void> saveRule(PriceAdjustmentRule rule) async {
    _upsertMemoryRule(rule);
    if (!isRemoteReady) return;
    await _client!.from('price_adjustment_rules').upsert(rule.toJson());
  }

  Future<void> deleteById(String id) async {
    _memoryRules.removeWhere((rule) => rule.id == id);
    if (!isRemoteReady || id.isEmpty) return;
    await _client!.from('price_adjustment_rules').delete().eq('id', id);
  }

  List<PriceAdjustmentRule> _sortedMemoryRules() {
    final rules = List<PriceAdjustmentRule>.from(_memoryRules);
    rules.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return rules;
  }

  void _upsertMemoryRule(PriceAdjustmentRule rule) {
    final index = _memoryRules.indexWhere((item) => item.id == rule.id);
    if (index == -1) {
      _memoryRules.add(rule);
      return;
    }
    _memoryRules[index] = rule;
  }
}
