import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzalteklif/models/quote.dart';
import 'package:uzalteklif/services/quote_editor_autosave_service.dart';
import 'package:uzalteklif/services/quote_repository.dart';

Quote _testQuote({String id = 'test-1'}) {
  return Quote(
    id: id,
    code: 'TST-001',
    customerName: 'Test',
    customerCompany: 'Test Inc',
    title: 'Test Quote',
    note: '',
    createdAt: DateTime(2026, 1, 1),
    displayUnit: 'TL',
    marketSnapshot: const [],
    items: const [
      QuoteLineItem(
        id: 'line-1',
        description: 'Test kalemi',
        quantity: 1,
        unit: 'adet',
        unitPriceTl: 100,
      ),
    ],
    documentProfile: const QuoteDocumentProfile(
      companyName: 'UZAL TEKNIK',
      companyTagline: '',
      companyPhone: '',
      companyEmail: '',
      companyWebsite: '',
      companyAddress: '',
      preparedByName: 'Test',
      preparedByTitle: '',
      preparedByPhone: '',
      preparedByEmail: '',
      customerContactTitle: '',
      customerPhone: '',
      customerEmail: '',
      validityText: '15 gun',
      paymentTerms: 'Pesin',
      deliveryTerms: 'Termin teyidi ile',
    ),
  );
}

class FakeConnectivityChecker implements ConnectivityChecker {
  bool _isOnline = true;
  final _controller = StreamController<bool>.broadcast();

  @override
  Stream<bool> get onConnectivityChanged => _controller.stream;

  @override
  Future<bool> get isOnline async => _isOnline;

  void setOnline(bool value) {
    _isOnline = value;
    _controller.add(value);
  }

  void dispose() => _controller.close();
}

class FakeQuoteRepository implements QuoteRepository {
  int saveCallCount = 0;
  bool shouldThrow = false;
  late bool lastForceOverwrite;

  @override
  Future<Quote> saveQuote(Quote quote, {bool forceOverwrite = false}) async {
    saveCallCount++;
    lastForceOverwrite = forceOverwrite;
    if (shouldThrow && !forceOverwrite) {
      throw Exception('Mock conflict');
    }
    return quote;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  group('QuoteEditorAutosaveService', () {
    late SharedPreferences prefs;
    late FakeQuoteRepository fakeRepository;
    late FakeConnectivityChecker fakeConnectivity;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      fakeRepository = FakeQuoteRepository();
      fakeConnectivity = FakeConnectivityChecker();
    });

    tearDown(() {
      fakeConnectivity.dispose();
    });

    test('debounce fires once after rapid markDirty calls', () async {
      final service = await QuoteEditorAutosaveService.create(
        quoteRepository: fakeRepository,
        buildQuote: () async => _testQuote(),
        draftKey: () => 'test-key',
        debounceDuration: const Duration(milliseconds: 50),
        connectivity: fakeConnectivity,
      );

      // Hizli ard arda uc degisiklik
      service.markDirty();
      service.markDirty();
      service.markDirty();

      // Debounce suresi dolmadan hicbir kayit olmamali
      await Future.delayed(const Duration(milliseconds: 20));
      expect(fakeRepository.saveCallCount, 0);

      // Sure dolunca uc isaretleme tek kayda indirgenmeli
      await Future.delayed(const Duration(milliseconds: 100));
      expect(fakeRepository.saveCallCount, 1);

      service.dispose();
    });

    test('forceOverwrite is true for autosave', () async {
      final service = await QuoteEditorAutosaveService.create(
        quoteRepository: fakeRepository,
        buildQuote: () async => _testQuote(),
        draftKey: () => 'test-key',
        debounceDuration: const Duration(milliseconds: 50),
        connectivity: fakeConnectivity,
      );

      service.markDirty();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(fakeRepository.lastForceOverwrite, true);
      service.dispose();
    });

    test('offline skips network write but saves recovery copy', () async {
      fakeConnectivity.setOnline(false);

      final service = await QuoteEditorAutosaveService.create(
        quoteRepository: fakeRepository,
        buildQuote: () async => _testQuote(),
        draftKey: () => 'offline-key',
        debounceDuration: const Duration(milliseconds: 50),
        connectivity: fakeConnectivity,
      );

      service.markDirty();
      await Future.delayed(const Duration(milliseconds: 100));

      expect(fakeRepository.saveCallCount, 0); // No network save
      expect(service.status, QuoteAutosaveStatus.offline);

      // Recovery copy should exist
      final recovery = prefs.getString('autosave_draft_offline-key');
      expect(recovery, isNotNull);

      service.dispose();
    });
  });
}
