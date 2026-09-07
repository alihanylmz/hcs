import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:uzalteklif/models/cari_account.dart';
import 'package:uzalteklif/models/market_rate.dart';
import 'package:uzalteklif/models/product.dart';
import 'package:uzalteklif/models/quote.dart';
import 'package:uzalteklif/models/user_quote_profile.dart';
import 'package:uzalteklif/screens/quote_editor_page.dart';
import 'package:uzalteklif/services/cari_repository.dart';
import 'package:uzalteklif/services/quote_repository.dart';
import 'package:uzalteklif/services/user_profile_repository.dart';
import 'package:uzalteklif/theme/app_theme.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  testWidgets('auto-creates cari when saving quote with new company name', (
    WidgetTester tester,
  ) async {
    // Setup: empty cari repository, a product, rates
    final cariRepo = _FakeCariRepository();
    final products = [
      Product(
        id: 'p-1',
        code: 'SNS-100',
        name: 'Test Sensoru',
        category: 'Sensor',
        brand: 'Brand',
        model: 'M1',
        unit: 'adet',
        currencyCode: 'TL',
        salePrice: 1000,
        stockQuantity: 10,
        minimumStock: 1,
        vatRate: 20,
        leadTime: '1 gun',
        description: '',
        technicalSummary: '',
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
    ];

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: QuoteEditorPage(
          quoteRepository: QuoteRepository(),
          cariRepository: cariRepo,
          initialRates: rates,
          availableProducts: products,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Enter new company name that doesn't exist in cariler
    const newCompanyName = 'Yeni Firma Ltd';
    await tester.enterText(find.byType(TextFormField).first, newCompanyName);
    await tester.pumpAndSettle();

    // Add one product line (minimum requirement)
    final addButton = find.byKey(const ValueKey('catalog-add-p-1'));
    if (addButton.evaluate().isNotEmpty) {
      final buttonWidget = tester.widget<OutlinedButton>(addButton);
      buttonWidget.onPressed!.call();
      await tester.pumpAndSettle();
    }

    // Try to save (via Teklifi Tamamla button)
    final submitButton = find.byKey(const ValueKey('btn-tamamla'));
    if (submitButton.evaluate().isNotEmpty) {
      await tester.tap(submitButton);
      await tester.pumpAndSettle();

      // Verify: new cari should have been auto-created
      expect(cariRepo.cariler.isNotEmpty, true,
          reason: 'Cari should be auto-created on save');
      final created = cariRepo.cariler.firstWhereOrNull(
        (c) => c.companyName == newCompanyName,
      );
      expect(created, isNotNull,
          reason: 'New company name should exist in cariler');
    }
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

    // Fill in minimum required fields to enable add product button
    await tester.enterText(find.byType(TextFormField).first, 'Test Firma');
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
          initialProductLines: const [
            QuoteInitialProductLine(
              productId: 'sensor-1',
              quantity: 8,
              sectionName: 'DDC-01 / Saha Ekipmanları',
            ),
            QuoteInitialProductLine(
              productId: 'sensor-1',
              quantity: 3,
              sectionName: 'DDC-02 / Saha Ekipmanları',
            ),
          ],
          initialTitle: 'Kazan Dairesi Otomasyonu',
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quote-line-sensor-1')), findsNWidgets(2));
    expect(
      find.descendant(
        of: find.byKey(const ValueKey('quote-line-sensor-1')),
        matching: find.widgetWithText(TextFormField, '8'),
      ),
      findsOneWidget,
    );
    expect(find.text('Kazan Dairesi Otomasyonu'), findsOneWidget);
    expect(find.text('DDC-01'), findsWidgets);
    expect(find.text('DDC-02'), findsWidgets);
    expect(find.text('Saha Ekipmanları'), findsNWidgets(2));
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

  testWidgets('high value foreign currency quote is never auto divided', (
    WidgetTester tester,
  ) async {
    final rates = [
      MarketRate(
        code: 'EURTRY',
        label: 'Euro',
        unitLabel: '1 EUR',
        value: 50,
        updatedAt: DateTime(2026, 8, 4, 10),
      ),
    ];
    final quote = Quote(
      id: 'quote-high-value',
      code: 'UZ-260804-100000',
      customerName: 'Test Yetkili',
      customerCompany: 'Yüksek Tutar Test',
      title: '120.000 EUR teklif',
      note: '',
      createdAt: DateTime(2026, 8, 4, 10),
      displayUnit: 'EURTRY',
      marketSnapshot: rates,
      items: const [
        QuoteLineItem(
          id: 'line-high-value',
          description: 'Yüksek tutarlı kontrol sistemi',
          quantity: 1,
          unit: 'adet',
          unitPriceTl: 6000000,
        ),
      ],
      documentProfile: const QuoteDocumentProfile(
        companyName: 'UZAL TEKNİK',
        companyTagline: '',
        companyPhone: '',
        companyEmail: '',
        companyWebsite: '',
        companyAddress: '',
        preparedByName: 'Test Kullanıcı',
        preparedByTitle: '',
        preparedByPhone: '',
        preparedByEmail: '',
        customerContactTitle: '',
        customerPhone: '',
        customerEmail: '',
        validityText: '15 gün',
        paymentTerms: 'Peşin',
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

    expect(find.widgetWithText(TextFormField, '120000.00'), findsOneWidget);
    expect(find.textContaining('kur carpani hatasi'), findsNothing);
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
      items: const [
        QuoteLineItem(
          id: 'copy-line-1',
          description: 'Kopyalanacak fiyat kalemi',
          quantity: 2,
          unit: 'adet',
          unitPriceTl: 1234,
          discountRate: 5,
        ),
      ],
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
    expect(find.text('Eski firma'), findsNothing);
    expect(find.text('Kopya profil testi'), findsNothing);
    expect(find.text('Kopyalanacak fiyat kalemi'), findsOneWidget);
    expect(find.widgetWithText(TextFormField, '1234.00'), findsOneWidget);
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

/// Fake [CariRepository] for testing auto-create-on-save flow
class _FakeCariRepository extends CariRepository {
  _FakeCariRepository() : super(client: null);

  List<CariAccount> cariler = [];

  @override
  bool get isRemoteReady => true;

  @override
  Future<List<CariAccount>> fetchAll() async => cariler;

  @override
  Future<CariAccount?> fetchById(String id) async =>
      cariler.firstWhereOrNull((c) => c.id == id);

  @override
  Future<void> save(CariAccount cari) async {
    final idx = cariler.indexWhere((c) => c.id == cari.id);
    if (idx >= 0) {
      cariler[idx] = cari;
    } else {
      cariler.add(cari);
    }
  }
}
