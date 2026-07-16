import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../config/app_config.dart';
import '../models/market_rate.dart';

class MarketRateService {
  const MarketRateService({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;

  Future<List<MarketRate>> fetchRates() async {
    final supabaseRates = await _fetchSupabaseRates();
    if (_isFresh(supabaseRates)) {
      return supabaseRates;
    }

    try {
      final liveRates = await _fetchLiveRates();
      await _saveSupabaseRates(liveRates);
      return liveRates;
    } catch (_) {
      if (supabaseRates.isNotEmpty) {
        return supabaseRates;
      }
      return _fallbackRates();
    }
  }

  Future<List<MarketRate>> refreshRates() async {
    try {
      final liveRates = await _fetchLiveRates();
      await _saveSupabaseRates(liveRates);
      return liveRates;
    } catch (_) {
      final supabaseRates = await _fetchSupabaseRates();
      if (supabaseRates.isNotEmpty) {
        return supabaseRates;
      }
      return _fallbackRates();
    }
  }

  bool _isFresh(List<MarketRate> rates) {
    if (rates.length < 2) {
      return false;
    }
    final oldest = rates
        .map((rate) => rate.updatedAt)
        .reduce((a, b) => a.isBefore(b) ? a : b);
    return DateTime.now().difference(oldest) <
        const Duration(minutes: AppConfig.ratesRefreshMinutes);
  }

  Future<List<MarketRate>> _fetchSupabaseRates() async {
    final client = _client;
    if (client == null) {
      return const [];
    }

    try {
      final rows = await client
          .from('market_rates')
          .select()
          .order('sort_order', ascending: true);

      return rows
          .cast<Map<String, dynamic>>()
          .map(MarketRate.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }

  Future<double> _fetchCurrencyRate(String base) async {
    final uri = Uri.parse('https://open.er-api.com/v6/latest/$base');
    final response = await http.get(uri).timeout(const Duration(seconds: 8));
    if (response.statusCode != 200) {
      throw Exception('Kur verisi alinamadi.');
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final rates = json['rates'] as Map<String, dynamic>? ?? const {};
    final tryValue = rates['TRY'];
    if (tryValue is! num) {
      throw Exception('TRY kuru bulunamadi.');
    }
    return tryValue.toDouble();
  }

  Future<List<MarketRate>> _fetchLiveRates() async {
    final usdTry = await _fetchCurrencyRate('USD');
    final eurTry = await _fetchCurrencyRate('EUR');
    final now = DateTime.now();

    return [
      MarketRate(
        code: 'USDTRY',
        label: 'Dolar',
        unitLabel: '1 USD',
        value: usdTry,
        updatedAt: now,
      ),
      MarketRate(
        code: 'EURTRY',
        label: 'Euro',
        unitLabel: '1 EUR',
        value: eurTry,
        updatedAt: now,
      ),
    ];
  }

  Future<void> _saveSupabaseRates(List<MarketRate> rates) async {
    final client = _client;
    if (client == null || client.auth.currentSession == null) {
      return;
    }

    try {
      await client.from('market_rates').upsert(
        [
          for (var i = 0; i < rates.length; i++)
            {
              ...rates[i].toJson(),
              'is_fallback': false,
              'sort_order': i,
            },
        ],
      );
    } catch (_) {
      // Canli kur ekranda kullanilir; Supabase snapshot yazilamazsa sessiz gec.
    }
  }

  List<MarketRate> _fallbackRates() {
    final now = DateTime.now();
    return [
      MarketRate(
        code: 'USDTRY',
        label: 'Dolar',
        unitLabel: '1 USD',
        value: 38.12,
        updatedAt: now,
        isFallback: true,
      ),
      MarketRate(
        code: 'EURTRY',
        label: 'Euro',
        unitLabel: '1 EUR',
        value: 41.26,
        updatedAt: now,
        isFallback: true,
      ),
    ];
  }
}
