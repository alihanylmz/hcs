import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:uzalteklif/models/market_rate.dart';
import 'package:uzalteklif/models/product.dart';
import 'package:uzalteklif/models/quote.dart';
import 'package:uzalteklif/models/user_quote_profile.dart';
import 'package:uzalteklif/screens/quote_editor_page.dart';
import 'package:uzalteklif/services/quote_repository.dart';
import 'package:uzalteklif/services/user_profile_repository.dart';
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

  testWidgets('discovery products open as quote lines with total quantities', (
    WidgetTester tester,
  ) async {
    final product = Product(
      id: 'sensor-1',
      code: 'SNS-100',
      name: 'Sıcaklık Sensörü',
      category: 'Sensörler',
      brand: 'Honeywell',
      model: 'T100',
      unit: 'adet',
      currencyCode: 'TL',
      salePrice: 1250,
      stockQuantity: 20,
      minimumStock: 2,
      vatRate: 20,
      leadTime: '',
      description: '',
      technicalSummary: '',
      isActive: true,
      updatedAt: DateTime(2026, 7, 30),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: QuoteEditorPage(
          quoteRepository: QuoteRepository(),
          initialRates: const [],
          availableProducts: [product],
          initialProductQuantities: const {'sensor-1': 8},
          initialTitle: 'Kazan Dairesi Otomasyonu',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quote-line-sensor-1')), findsOneWidget);
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('quote-line-sensor-1')),
        matching: find.widgetWithText(TextFormField, '8'),
      ),
      findsOneWidget,
    );
    expect(find.text('Kazan Dairesi Otomasyonu'), findsOneWidget);
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

  testWidgets('copied quote uses current user profile in prepared-by fields', (
    WidgetTester tester,
  ) async {
    final source = Quote(
      id: 'quote-copy-source',
      code: 'UZ-260730-100000',
      customerName: 'Eski müşteri',
      customerCompany: 'Eski firma',
      title: 'Kopya profil testi',
      note: '',
      createdAt: DateTime(2026, 7, 30, 10),
      displayUnit: 'TL',
      marketSnapshot: const [],
      items: const [],
      documentProfile: const QuoteDocumentProfile(
        companyName: 'UZAL TEKNİK',
        companyTagline: '',
        companyPhone: '',
        companyEmail: '',
        companyWebsite: '',
        companyAddress: '',
        preparedByName: 'Eski Kullanıcı',
        preparedByTitle: 'Eski Unvan',
        preparedByPhone: '+90 500 000 00 00',
        preparedByEmail: 'eski@example.com',
        customerContactTitle: '',
        customerPhone: '',
        customerEmail: '',
        validityText: '15 gün',
        paymentTerms: 'Peşin',
        deliveryTerms: 'Termin teyidi ile',
      ),
    );
    final profile = _userProfile(
      name: 'Güncel Kullanıcı',
      title: 'Satış Mühendisi',
      phone: '+90 555 111 22 33',
      email: 'guncel@example.com',
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: QuoteEditorPage(
          quoteRepository: QuoteRepository(),
          initialRates: const [],
          availableProducts: const [],
          quoteToCopy: source,
          userProfileRepository: _FakeUserProfileRepository(profile),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('Bilgileri Düzenle'));
    await tester.pumpAndSettle();

    expect(find.text('Güncel Kullanıcı'), findsOneWidget);
    expect(find.text('+90 555 111 22 33'), findsOneWidget);
    expect(find.text('+90 500 000 00 00', skipOffstage: false), findsNothing);
  });
}

class _FakeUserProfileRepository extends UserProfileRepository {
  _FakeUserProfileRepository(this.profile);

  final UserQuoteProfile profile;

  @override
  Future<UserQuoteProfile?> fetchMine() async => profile;
}

UserQuoteProfile _userProfile({
  required String name,
  required String title,
  required String phone,
  required String email,
}) {
  return UserQuoteProfile(
    userId: 'current-user',
    preparedByName: name,
    preparedByTitle: title,
    preparedByPhone: phone,
    preparedByEmail: email,
    companyName: '',
    companyTagline: '',
    companyPhone: '',
    companyEmail: '',
    companyWebsite: '',
    companyAddress: '',
    companyTaxOffice: '',
    companyTaxNumber: '',
    companyMersis: '',
    bankName: '',
    bankBranch: '',
    bankAccountName: '',
    bankIban: '',
    bankSwift: '',
    defaultValidityText: '15 gün',
    defaultPaymentTerms: 'Peşin',
    defaultDeliveryTerms: 'Termin teyidi ile',
    defaultVatRate: 20,
  );
}
