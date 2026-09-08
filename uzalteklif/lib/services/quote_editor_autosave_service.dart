import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quote.dart';

enum QuoteAutosaveStatus { idle, dirty, saving, saved }

/// Teklif editorunde otomatik YEREL taslak: kullanici yazmayi biraktiktan
/// [debounceDuration] sonra teklifin anlik halini cihaza yazar.
///
/// Bilerek sunucuya yazmaz. `quotes` tablosunda her UPDATE'te calisan uc
/// trigger var: `quotes_capture_revision` (kosulsuz, revizyon gecmisine tam
/// snapshot ekler), `quotes_audit_log` (satirin iki tam kopyasi) ve
/// `quotes_sync_line_items` (tum kalemleri silip yeniden yazar). Otomatik
/// kayit bunlari tetikleseydi revizyon gecmisi oturum basina onlarca sahte
/// kayitla dolar ve kullanilamaz hale gelirdi. Ayrica sunucuya yazmak
/// cakisma kontrolunu atlamayi gerektirdigi icin ayni teklifi acan iki
/// kullanicidan biri digerinin isini sessizce ezerdi.
///
/// Yerel kopya cokme, sekme kapatma ve yenileme senaryolarini karsilar.
/// Karsilamadigi tek senaryo: taslak yalnizca yazildigi tarayicida durur,
/// baska bir cihazdan acilinca orada olmaz.
class QuoteEditorAutosaveService extends ChangeNotifier {
  QuoteEditorAutosaveService({
    required Future<Quote?> Function() buildQuote,
    required String Function() draftKey,
    this.debounceDuration = const Duration(seconds: 12),
  }) : _buildQuote = buildQuote,
       _draftKey = draftKey;

  final Future<Quote?> Function() _buildQuote;
  final String Function() _draftKey;
  final Duration debounceDuration;

  late SharedPreferences _prefs;
  Timer? _debounceTimer;
  QuoteAutosaveStatus _status = QuoteAutosaveStatus.idle;
  bool _isDirty = false;

  QuoteAutosaveStatus get status => _status;
  bool get isDirty => _isDirty;

  /// Factory to async-initialize the service
  static Future<QuoteEditorAutosaveService> create({
    required Future<Quote?> Function() buildQuote,
    required String Function() draftKey,
    Duration debounceDuration = const Duration(seconds: 12),
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final service = QuoteEditorAutosaveService(
      buildQuote: buildQuote,
      draftKey: draftKey,
      debounceDuration: debounceDuration,
    );
    service._prefs = prefs;
    return service;
  }

  /// Mark the form as dirty, starting a debounce timer for autosave
  void markDirty() {
    if (_status == QuoteAutosaveStatus.saving) {
      return; // Don't restart timer while saving
    }

    _isDirty = true;
    _status = QuoteAutosaveStatus.dirty;
    notifyListeners();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounceDuration, saveNow);
  }

  /// Taslagi cihaza yazar. Debounce timer'i veya acik cagrilar tetikler.
  Future<void> saveNow({bool isFinal = false}) async {
    if (_status == QuoteAutosaveStatus.saving) {
      return; // Already saving
    }

    _debounceTimer?.cancel();
    _status = QuoteAutosaveStatus.saving;
    notifyListeners();

    try {
      final quote = await _buildQuote();
      if (quote == null) {
        // Form henuz gecerli degil (zorunlu alan bos, kalem yok gibi).
        _status = _isDirty
            ? QuoteAutosaveStatus.dirty
            : QuoteAutosaveStatus.idle;
        notifyListeners();
        return;
      }

      await _writeRecoveryCopy(quote);
      if (isFinal) {
        await discardRecoveryDraft(_draftKey());
      }

      _isDirty = false;
      _status = QuoteAutosaveStatus.saved;
      notifyListeners();
    } catch (error) {
      // Yerel yazma basarisiz olduysa (ornegin depolama dolu/engelli) kirli
      // kal ki sonraki degisiklikte tekrar denensin.
      _status = _isDirty ? QuoteAutosaveStatus.dirty : QuoteAutosaveStatus.idle;
      notifyListeners();
    }
  }

  /// Read recovery draft from SharedPreferences
  Future<RecoveryDraft?> readRecoveryDraft(String key) async {
    final json = _prefs.getString('autosave_draft_$key');
    if (json == null) return null;

    try {
      final Map<String, dynamic> decoded = Map<String, dynamic>.from(
        jsonDecode(json),
      );
      return RecoveryDraft(
        quote: Quote.fromJson(decoded['quote']),
        savedAt: DateTime.parse(decoded['savedAt']),
      );
    } catch (e) {
      return null;
    }
  }

  /// Write recovery copy to SharedPreferences
  Future<void> _writeRecoveryCopy(Quote quote) async {
    final data = {
      'quote': quote.toJson(),
      'savedAt': DateTime.now().toUtc().toIso8601String(),
    };
    await _prefs.setString('autosave_draft_${_draftKey()}', jsonEncode(data));
  }

  /// Discard recovery draft
  Future<void> discardRecoveryDraft(String key) async {
    await _prefs.remove('autosave_draft_$key');
  }

  /// Cleanup on dispose
  void flushAndDispose() {
    _debounceTimer?.cancel();
  }

  @override
  void dispose() {
    flushAndDispose();
    super.dispose();
  }
}

class RecoveryDraft {
  final Quote quote;
  final DateTime savedAt;

  RecoveryDraft({required this.quote, required this.savedAt});
}
