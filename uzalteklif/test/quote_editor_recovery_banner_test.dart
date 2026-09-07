import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:uzalteklif/models/quote.dart';
import 'package:uzalteklif/screens/quote_editor_page.dart';
import 'package:uzalteklif/services/quote_editor_autosave_service.dart';
import 'package:uzalteklif/services/quote_repository.dart';
import 'package:uzalteklif/theme/app_theme.dart';

Quote _draftQuote() {
  return Quote(
    id: 'new',
    code: 'UZ-260908-120000',
    customerName: 'Kurtarilan Yetkili',
    customerCompany: 'Kurtarilan Firma',
    title: 'Kurtarilan teklif konusu',
    note: '',
    createdAt: DateTime(2026, 9, 8, 12),
    displayUnit: 'TL',
    marketSnapshot: const [],
    items: const [
      QuoteLineItem(
        id: 'line-1',
        description: 'Kurtarilan kalem',
        quantity: 2,
        unit: 'adet',
        unitPriceTl: 500,
      ),
    ],
    documentProfile: const QuoteDocumentProfile(
      companyName: 'UZAL TEKNIK',
      companyTagline: '',
      companyPhone: '',
      companyEmail: '',
      companyWebsite: '',
      companyAddress: '',
      preparedByName: '',
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

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('kurtarma taslagi varsa bant cikar ve geri yukleme formu doldurur', (
    WidgetTester tester,
  ) async {
    // Editor acilmadan once diskte bir kurtarma kopyasi hazirla.
    SharedPreferences.setMockInitialValues({
      'autosave_draft_new': jsonEncode({
        'quote': _draftQuote().toJson(),
        'savedAt': DateTime(2026, 9, 8, 12, 30).toUtc().toIso8601String(),
      }),
    });

    // Debounce'u testin uzerinde hic ateslenmeyecek kadar uzun tutuyoruz;
    // bekleyen timer pumpAndSettle'i kilitlemesin.
    final service = await QuoteEditorAutosaveService.create(
      quoteRepository: QuoteRepository(),
      buildQuote: () async => null,
      draftKey: () => 'new',
      debounceDuration: const Duration(hours: 1),
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: QuoteEditorPage(
          quoteRepository: QuoteRepository(),
          initialRates: const [],
          availableProducts: const [],
          autosaveService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('kaydedilmemis bir taslak bulundu'),
      findsOneWidget,
      reason: 'Diskte taslak varken kurtarma bandi gorunmeli',
    );

    await tester.tap(find.text('Geri Yukle'));
    await tester.pumpAndSettle();

    expect(find.text('Kurtarilan Firma'), findsWidgets);
    expect(find.text('Kurtarilan Yetkili'), findsWidgets);
    expect(find.text('Taslak geri yuklendi.'), findsOneWidget);

    // Geri yukleme sonrasi kopya temizlenmeli, yoksa tekrar acilista
    // ayni bant bir daha cikar.
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('autosave_draft_new'), isNull);
  });

  testWidgets('taslak yoksa kurtarma bandi cikmaz', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});

    final service = await QuoteEditorAutosaveService.create(
      quoteRepository: QuoteRepository(),
      buildQuote: () async => null,
      draftKey: () => 'new',
      debounceDuration: const Duration(hours: 1),
    );
    addTearDown(service.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: QuoteEditorPage(
          quoteRepository: QuoteRepository(),
          initialRates: const [],
          availableProducts: const [],
          autosaveService: service,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.textContaining('kaydedilmemis bir taslak'), findsNothing);
  });
}
