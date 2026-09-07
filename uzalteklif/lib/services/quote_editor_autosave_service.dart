import 'dart:async';
import 'dart:convert';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/quote.dart';
import 'quote_repository.dart';

enum QuoteAutosaveStatus { idle, dirty, saving, saved, offline, conflict }

/// Autosave service for quote editor with debounce, local recovery, and offline support.
class QuoteEditorAutosaveService extends ChangeNotifier {
  QuoteEditorAutosaveService({
    required QuoteRepository quoteRepository,
    required Future<Quote?> Function() buildQuote,
    required String Function() draftKey,
    this.debounceDuration = const Duration(seconds: 12),
    ConnectivityChecker? connectivity,
  })  : _quoteRepository = quoteRepository,
        _buildQuote = buildQuote,
        _draftKey = draftKey,
        _connectivity = connectivity ?? DefaultConnectivityChecker();

  final QuoteRepository _quoteRepository;
  final Future<Quote?> Function() _buildQuote;
  final String Function() _draftKey;
  final Duration debounceDuration;
  final ConnectivityChecker _connectivity;

  late SharedPreferences _prefs;
  Timer? _debounceTimer;
  QuoteAutosaveStatus _status = QuoteAutosaveStatus.idle;
  bool _isDirty = false;
  StreamSubscription? _connectivitySubscription;

  QuoteAutosaveStatus get status => _status;
  bool get isDirty => _isDirty;

  /// Factory to async-initialize the service
  static Future<QuoteEditorAutosaveService> create({
    required QuoteRepository quoteRepository,
    required Future<Quote?> Function() buildQuote,
    required String Function() draftKey,
    Duration debounceDuration = const Duration(seconds: 12),
    ConnectivityChecker? connectivity,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final service = QuoteEditorAutosaveService(
      quoteRepository: quoteRepository,
      buildQuote: buildQuote,
      draftKey: draftKey,
      debounceDuration: debounceDuration,
      connectivity: connectivity,
    );
    service._prefs = prefs;
    service._subscribeToConnectivity();
    return service;
  }

  void _subscribeToConnectivity() {
    _connectivitySubscription =
        _connectivity.onConnectivityChanged.listen((isOnline) {
      if (isOnline && _isDirty) {
        saveNow();
      }
    });
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

  /// Manually trigger a save (called by debounce timer or explicit calls)
  Future<void> saveNow({bool isFinal = false}) async {
    if (_status == QuoteAutosaveStatus.saving) {
      return; // Already saving
    }

    _debounceTimer?.cancel();
    _status = QuoteAutosaveStatus.saving;
    notifyListeners();

    try {
      final isOnline = await _connectivity.isOnline;
      if (!isOnline) {
        // Offline: save recovery copy only
        final quote = await _buildQuote();
        if (quote != null) {
          await _writeRecoveryCopy(quote);
        }
        _status = QuoteAutosaveStatus.offline;
        notifyListeners();
        return;
      }

      // Online: build and save
      final quote = await _buildQuote();
      if (quote == null) {
        // Validation not ready yet
        _status = _isDirty ? QuoteAutosaveStatus.dirty : QuoteAutosaveStatus.idle;
        notifyListeners();
        return;
      }

      // Write recovery copy before network call
      await _writeRecoveryCopy(quote);

      // Call repository with forceOverwrite=true for autosave
      await _quoteRepository.saveQuote(quote, forceOverwrite: true);

      // Success
      _isDirty = false;
      _status = QuoteAutosaveStatus.saved;
      if (isFinal) {
        await discardRecoveryDraft(_draftKey());
      } else {
        // Keep recovery copy fresh, re-write on next dirty tick
      }
      notifyListeners();
    } catch (error) {
      // Network error or other failure
      if (error.toString().contains('SocketException') ||
          error.toString().contains('TimeoutException')) {
        _status = QuoteAutosaveStatus.offline;
      } else {
        _status =
            _isDirty ? QuoteAutosaveStatus.dirty : QuoteAutosaveStatus.idle;
      }
      notifyListeners();
    }
  }

  /// Read recovery draft from SharedPreferences
  Future<RecoveryDraft?> readRecoveryDraft(String key) async {
    final json = _prefs.getString('autosave_draft_$key');
    if (json == null) return null;

    try {
      final Map<String, dynamic> decoded =
          Map<String, dynamic>.from(jsonDecode(json));
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
    await _prefs.setString(
      'autosave_draft_${_draftKey()}',
      jsonEncode(data),
    );
  }

  /// Discard recovery draft
  Future<void> discardRecoveryDraft(String key) async {
    await _prefs.remove('autosave_draft_$key');
  }

  /// Cleanup on dispose
  void flushAndDispose() {
    _debounceTimer?.cancel();
    _connectivitySubscription?.cancel();
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

/// Minimal connectivity abstraction for testability
abstract class ConnectivityChecker {
  Stream<bool> get onConnectivityChanged;
  Future<bool> get isOnline;
}

class DefaultConnectivityChecker implements ConnectivityChecker {
  final _connectivity = Connectivity();

  /// connectivity_plus v6 tek bir enum degil `List<ConnectivityResult>`
  /// dondurur. Listeyi dogrudan `ConnectivityResult.none` ile karsilastirmak
  /// her zaman true verir ve cevrimdisi durumu hic yakalanmaz; bu yuzden
  /// listenin icine bakiyoruz. Bos liste de cevrimdisi sayilir.
  static bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);

  @override
  Stream<bool> get onConnectivityChanged {
    return _connectivity.onConnectivityChanged.map(_isOnline).distinct();
  }

  @override
  Future<bool> get isOnline async {
    return _isOnline(await _connectivity.checkConnectivity());
  }
}
