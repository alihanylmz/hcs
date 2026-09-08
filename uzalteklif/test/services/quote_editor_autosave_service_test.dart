import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:uzalteklif/models/quote.dart';
import 'package:uzalteklif/services/quote_editor_autosave_service.dart';

Quote _testQuote({String id = 'test-1', String note = ''}) {
  return Quote(
    id: id,
    code: 'TST-001',
    customerName: 'Test',
    customerCompany: 'Test Inc',
    title: 'Test Quote',
    note: note,
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('QuoteEditorAutosaveService', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    test('hizli ard arda degisiklikler tek yazmaya indirgenir', () async {
      var buildCount = 0;
      final service = await QuoteEditorAutosaveService.create(
        buildQuote: () async {
          buildCount++;
          return _testQuote();
        },
        draftKey: () => 'test-key',
        debounceDuration: const Duration(milliseconds: 50),
      );
      addTearDown(service.dispose);

      service.markDirty();
      service.markDirty();
      service.markDirty();

      // Debounce dolmadan hicbir sey yazilmamali.
      await Future.delayed(const Duration(milliseconds: 20));
      expect(buildCount, 0);
      expect(prefs.getString('autosave_draft_test-key'), isNull);

      // Dolunca uc isaretleme tek yazmaya inmeli.
      await Future.delayed(const Duration(milliseconds: 100));
      expect(buildCount, 1);
      expect(prefs.getString('autosave_draft_test-key'), isNotNull);
      expect(service.status, QuoteAutosaveStatus.saved);
    });

    test('taslak yalnizca cihaza yazilir, sunucuya gidilmez', () async {
      // Servis artik QuoteRepository almiyor; sunucuya yazma yolu yok.
      // Bu test o sozlesmeyi sabitliyor: kayit sonrasi tek etki yerel kopya.
      final service = await QuoteEditorAutosaveService.create(
        buildQuote: () async => _testQuote(note: 'Kullanici notu'),
        draftKey: () => 'local-key',
        debounceDuration: const Duration(milliseconds: 20),
      );
      addTearDown(service.dispose);

      service.markDirty();
      await Future.delayed(const Duration(milliseconds: 60));

      final stored = prefs.getString('autosave_draft_local-key');
      expect(stored, isNotNull);
      expect(stored, contains('Kullanici notu'));
    });

    test('form gecerli degilse taslak yazilmaz', () async {
      final service = await QuoteEditorAutosaveService.create(
        buildQuote: () async => null,
        draftKey: () => 'invalid-key',
        debounceDuration: const Duration(milliseconds: 20),
      );
      addTearDown(service.dispose);

      service.markDirty();
      await Future.delayed(const Duration(milliseconds: 60));

      expect(prefs.getString('autosave_draft_invalid-key'), isNull);
    });

    test('readRecoveryDraft yazilan taslagi geri okur', () async {
      final service = await QuoteEditorAutosaveService.create(
        buildQuote: () async => _testQuote(note: 'Geri okunacak'),
        draftKey: () => 'roundtrip-key',
        debounceDuration: const Duration(milliseconds: 20),
      );
      addTearDown(service.dispose);

      service.markDirty();
      await Future.delayed(const Duration(milliseconds: 60));

      final draft = await service.readRecoveryDraft('roundtrip-key');
      expect(draft, isNotNull);
      expect(draft!.quote.note, 'Geri okunacak');
      expect(draft.quote.items, hasLength(1));
    });

    test('isFinal: true kalici kayittan sonra kopyayi siler', () async {
      final service = await QuoteEditorAutosaveService.create(
        buildQuote: () async => _testQuote(),
        draftKey: () => 'final-key',
        debounceDuration: const Duration(milliseconds: 20),
      );
      addTearDown(service.dispose);

      await service.saveNow();
      expect(prefs.getString('autosave_draft_final-key'), isNotNull);

      await service.saveNow(isFinal: true);
      expect(prefs.getString('autosave_draft_final-key'), isNull);
    });

    test('discardRecoveryDraft kopyayi siler', () async {
      final service = await QuoteEditorAutosaveService.create(
        buildQuote: () async => _testQuote(),
        draftKey: () => 'discard-key',
        debounceDuration: const Duration(milliseconds: 20),
      );
      addTearDown(service.dispose);

      await service.saveNow();
      expect(prefs.getString('autosave_draft_discard-key'), isNotNull);

      await service.discardRecoveryDraft('discard-key');
      expect(prefs.getString('autosave_draft_discard-key'), isNull);
    });
  });
}
