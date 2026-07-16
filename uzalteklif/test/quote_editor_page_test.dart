import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:uzalteklif/models/market_rate.dart';
import 'package:uzalteklif/models/product.dart';
import 'package:uzalteklif/models/quote.dart';
import 'package:uzalteklif/screens/quote_editor_page.dart';
import 'package:uzalteklif/services/quote_repository.dart';
import 'package:uzalteklif/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('quote editor shows code plate and adds product lines', (
    WidgetTester tester,
  ) async {
    final products = [
      Product(
        id: 'p-1',
        code: 'SNS-QAE-2120',
        name: 'Kanal Tipi Sicaklik Sensoru',
        category: 'Sensor',
        brand: 'Siemens',
        model: 'QAE2120.010',
        unit: 'adet',
        currencyCode: 'TL',
        salePrice: 1850,
        stockQuantity: 12,
        minimumStock: 4,
        vatRate: 20,
        leadTime: '2 is gunu',
        description: 'Test urunu',
        technicalSummary: 'PT1000',
        isActive: true,
        updatedAt: DateTime(2026, 4, 21, 12),
      ),
    ];

    final rates = [
      MarketRate(
        code: 'USDTRY',
        label: 'Dolar',
        unitLabel: '1 USD',
        value: 38.2,
        updatedAt: DateTime(2026, 4, 21, 12),
      ),
      MarketRate(
        code: 'EURTRY',
        label: 'Euro',
        unitLabel: '1 EUR',
        value: 41.7,
        updatedAt: DateTime(2026, 4, 21, 12),
      ),
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: QuoteEditorPage(
          quoteRepository: QuoteRepository(),
          initialRates: rates,
          availableProducts: products,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Teklif Kodu'), findsOneWidget);
    expect(find.textContaining('UZ-'), findsWidgets);

    final addButton = find.byKey(const ValueKey('catalog-add-p-1'));
    final buttonWidget = tester.widget<OutlinedButton>(addButton);
    buttonWidget.onPressed!.call();
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quote-line-p-1')), findsOneWidget);

    await tester.tap(find.text('Ozel Kalem Ekle'));
    await tester.pumpAndSettle();

    expect(find.text('Kalem Aciklamasi'), findsWidgets);
    expect(find.text('Ozel kalem'), findsOneWidget);
  });

  testWidgets('custom line prices open in display currency when revising', (
    WidgetTester tester,
  ) async {
    final rates = [
      MarketRate(
        code: 'EURTRY',
        label: 'Euro',
        unitLabel: '1 EUR',
        value: 40,
        updatedAt: DateTime(2026, 4, 21, 12),
      ),
    ];

    final quote = Quote(
      id: 'quote-1',
      code: 'UZ-260421-120000',
      customerName: 'Ali Uzal',
      customerCompany: 'Uzal Teknik',
      title: 'Revizyon testi',
      note: 'Test',
      createdAt: DateTime(2026, 4, 21, 12),
      displayUnit: 'EURTRY',
      marketSnapshot: rates,
      items: const [
        QuoteLineItem(
          id: 'line-custom',
          description: 'Ozel pano hizmeti',
          quantity: 1,
          unit: 'adet',
          unitPriceTl: 4000,
        ),
      ],
      documentProfile: const QuoteDocumentProfile(
        companyName: 'UZAL TEKNIK',
        companyTagline: '',
        companyPhone: '',
        companyEmail: '',
        companyWebsite: '',
        companyAddress: '',
        preparedByName: 'Alihan Uzal',
        preparedByTitle: 'Satis Muhendisi',
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

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: QuoteEditorPage(
          quoteRepository: QuoteRepository(),
          initialRates: rates,
          availableProducts: const [],
          quoteToRevise: quote,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.widgetWithText(TextFormField, '100.00'), findsOneWidget);
  });
}
