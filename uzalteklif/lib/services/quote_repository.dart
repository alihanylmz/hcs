import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/market_rate.dart';
import '../models/quote.dart';
import 'quote_code_generator.dart';

class QuoteRepository {
  QuoteRepository({SupabaseClient? client}) : _client = client;

  final SupabaseClient? _client;
  static final Map<String, Future<Quote>> _saveQueue = {};

  static final List<Quote> _memoryQuotes = [
    Quote(
      id: 'seed-001',
      code: 'UZ-260420-101530',
      customerName: 'Ayse Kaya',
      customerCompany: 'Marmara Endustri',
      title: 'Lazer Kesim ve Montaj Paketi',
      note: 'Teslim suresi 7 is gunu. KDV harictir.',
      createdAt: DateTime.now().subtract(const Duration(days: 1)),
      displayUnit: 'USDTRY',
      marketSnapshot: [
        MarketRate(
          code: 'USDTRY',
          label: 'Dolar',
          unitLabel: '1 USD',
          value: 38.12,
          updatedAt: DateTime.now(),
        ),
        MarketRate(
          code: 'EURTRY',
          label: 'Euro',
          unitLabel: '1 EUR',
          value: 41.26,
          updatedAt: DateTime.now(),
        ),
      ],
      items: const [
        QuoteLineItem(
          id: 'line-1',
          description: 'Sase imalat kalemi',
          quantity: 3,
          unit: 'adet',
          unitPriceTl: 18500,
          discountRate: 4,
        ),
        QuoteLineItem(
          id: 'line-2',
          description: 'Boya ve paketleme',
          quantity: 1,
          unit: 'paket',
          unitPriceTl: 6200,
        ),
      ],
      documentProfile: const QuoteDocumentProfile(
        companyName: 'UZAL TEKNIK',
        companyTagline: 'Mekanik ve Otomasyon Cozumleri',
        companyPhone: '+90 216 000 00 00',
        companyEmail: 'teklif@uzalteknik.com',
        companyWebsite: 'www.uzalteknik.com',
        companyAddress: 'Istanbul, Turkiye',
        preparedByName: 'Ali Han',
        preparedByTitle: 'Satis Muhendisi',
        preparedByPhone: '+90 555 100 10 10',
        preparedByEmail: 'teklif@uzalteknik.com',
        customerContactTitle: 'Satinalma Muduru',
        customerPhone: '+90 532 400 20 20',
        customerEmail: 'satinalma@marmaraendustri.com',
        validityText: '15 gun',
        paymentTerms: 'Pesin veya mutabakata gore vade',
        deliveryTerms: '7 is gunu',
      ),
      createdByName: 'Ali Han',
    ),
  ];

  Future<List<Quote>> fetchQuotes() async {
    if (_client == null) {
      return _sortedMemoryQuotes();
    }

    final rows = await _client
        .from('quotes')
        .select()
        .order('created_at', ascending: false);

    return rows
        .cast<Map<String, dynamic>>()
        .map(Quote.fromJson)
        .toList(growable: false);
  }

  Future<Quote> saveQuote(Quote quote) async {
    final previous = _saveQueue[quote.id] ?? Future<Quote>.value(quote);
    late final Future<Quote> current;
    current = previous
        .catchError((_) => quote)
        .then((_) => _saveQuoteNow(quote))
        .whenComplete(() {
          if (identical(_saveQueue[quote.id], current)) {
            _saveQueue.remove(quote.id);
          }
        });
    _saveQueue[quote.id] = current;
    return current;
  }

  Future<Quote> _saveQuoteNow(Quote quote) async {
    if (_client == null) {
      final saved = quote.copyWith(
        updatedAt: quote.updatedAt ?? DateTime.now().toUtc(),
      );
      _upsertMemoryQuote(saved);
      return saved;
    }

    try {
      final payload = Map<String, dynamic>.from(quote.toJson())
        ..remove('updated_at');
      if (quote.updatedAt == null) {
        final rows = await _client
            .from('quotes')
            .upsert(payload)
            .select('updated_at');
        final saved = quote.copyWith(
          updatedAt: _parseUpdatedAt(rows.first['updated_at']),
        );
        _upsertMemoryQuote(saved);
        return saved;
      }

      final rows = await _client
          .from('quotes')
          .update(payload)
          .eq('id', quote.id)
          .eq('updated_at', quote.updatedAt!.toUtc().toIso8601String())
          .select('updated_at');
      if (rows.isEmpty) {
        throw QuoteConflictException(quote.id);
      }
      final saved = quote.copyWith(
        updatedAt: _parseUpdatedAt(rows.first['updated_at']),
      );
      _upsertMemoryQuote(saved);
      return saved;
    } on PostgrestException catch (error) {
      if (_isMissingSharedWithColumn(error)) {
        final payload = Map<String, dynamic>.from(quote.toJson())
          ..remove('shared_with')
          ..remove('updated_at');
        if (quote.updatedAt == null) {
          final rows = await _client
              .from('quotes')
              .upsert(payload)
              .select('updated_at');
          final saved = quote.copyWith(
            updatedAt: _parseUpdatedAt(rows.first['updated_at']),
          );
          _upsertMemoryQuote(saved);
          return saved;
        }
        final rows = await _client
            .from('quotes')
            .update(payload)
            .eq('id', quote.id)
            .eq('updated_at', quote.updatedAt!.toUtc().toIso8601String())
            .select('updated_at');
        if (rows.isEmpty) throw QuoteConflictException(quote.id);
        final saved = quote.copyWith(
          updatedAt: _parseUpdatedAt(rows.first['updated_at']),
        );
        _upsertMemoryQuote(saved);
        return saved;
      }
      rethrow;
    }
  }

  DateTime _parseUpdatedAt(Object? value) {
    final raw = value?.toString();
    return DateTime.tryParse(raw ?? '')?.toUtc() ?? DateTime.now().toUtc();
  }

  /// Teklif kodu gun + ay + yil + saat + dakika biciminde uretilir.
  Future<String> generateQuoteCode({DateTime? date}) async {
    final target = date ?? DateTime.now();
    return QuoteCodeGenerator.buildCode(timestamp: target);
  }

  List<Quote> _sortedMemoryQuotes() {
    final quotes = List<Quote>.from(_memoryQuotes);
    quotes.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return quotes;
  }

  void _upsertMemoryQuote(Quote quote) {
    final index = _memoryQuotes.indexWhere((item) => item.id == quote.id);
    if (index == -1) {
      _memoryQuotes.add(quote);
      return;
    }
    _memoryQuotes[index] = quote;
  }

  /// Teklifin e-posta gonderim bilgisini gunceller.
  /// Memory modunda sadece local listeyi degistirir.
  Future<void> markEmailSent(String quoteId, String sentTo) async {
    final now = DateTime.now().toUtc();
    final index = _memoryQuotes.indexWhere((q) => q.id == quoteId);
    if (index != -1) {
      _memoryQuotes[index] = _memoryQuotes[index].copyWith(
        emailSentAt: now,
        emailSentTo: sentTo,
      );
    }
    if (_client == null) return;
    await _client.from('quotes').update({
      'email_sent_at': now.toIso8601String(),
      'email_sent_to': sentTo,
    }).eq('id', quoteId);
  }

  /// Musterinin teklif kararini gunceller.
  Future<void> updateCustomerResponse(
    String quoteId,
    CustomerResponse response,
  ) async {
    final index = _memoryQuotes.indexWhere((q) => q.id == quoteId);
    if (index != -1) {
      _memoryQuotes[index] = _memoryQuotes[index].copyWith(
        customerResponse: response,
      );
    }
    if (_client == null) return;
    await _client.from('quotes').update({
      'customer_response': response.storageKey,
    }).eq('id', quoteId);
  }

  /// Teklifin paylasildigi kisiler listesini gunceller.
  Future<void> updateSharedWith(
    String quoteId,
    List<String> sharedWith,
  ) async {
    final index = _memoryQuotes.indexWhere((q) => q.id == quoteId);
    if (index != -1) {
      _memoryQuotes[index] = _memoryQuotes[index].copyWith(
        sharedWith: sharedWith,
      );
    }
    if (_client == null) return;
    try {
      await _client.from('quotes').update({
        'shared_with': sharedWith,
      }).eq('id', quoteId);
    } on PostgrestException catch (error) {
      if (_isMissingSharedWithColumn(error)) {
        return;
      }
      rethrow;
    }
  }

  bool _isMissingSharedWithColumn(PostgrestException error) {
    final message = error.message.toLowerCase();
    return error.code == 'PGRST204' && message.contains('shared_with');
  }
}

class QuoteConflictException implements Exception {
  QuoteConflictException(this.quoteId);

  final String quoteId;

  @override
  String toString() =>
      'Bu teklif siz açtıktan sonra başka bir kullanıcı tarafından değiştirildi. '
      'Yeni sürümü yükleyip değişikliklerinizi tekrar kontrol edin.';
}

