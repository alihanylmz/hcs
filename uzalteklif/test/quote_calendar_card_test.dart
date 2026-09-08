import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:uzalteklif/models/quote.dart';
import 'package:uzalteklif/widgets/quote_calendar_card.dart';

Quote _quote({
  String id = 'q',
  QuoteStatus status = QuoteStatus.draft,
  DateTime? createdAt,
  DateTime? emailSentAt,
  String company = 'Test Firma',
}) {
  return Quote(
    id: id,
    code: 'UZ-$id',
    customerName: 'Yetkili',
    customerCompany: company,
    title: 'Konu',
    note: '',
    createdAt: createdAt ?? DateTime(2026, 9, 1),
    displayUnit: 'TL',
    marketSnapshot: const [],
    status: status,
    emailSentAt: emailSentAt,
    items: const [],
    documentProfile: const QuoteDocumentProfile(
      companyName: '',
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
      paymentTerms: '',
      deliveryTerms: '',
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await initializeDateFormatting('tr_TR');
  });

  Future<void> pump(
    WidgetTester tester,
    List<Quote> quotes, {
    ValueChanged<Quote>? onTap,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: QuoteCalendarCard(
              quotes: quotes,
              onQuoteTap: onTap ?? (_) {},
              today: DateTime(2026, 9, 10),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('icinde bulunulan ayi ve aciklamayi gosterir', (tester) async {
    await pump(tester, const []);

    expect(find.textContaining('Eylül'), findsOneWidget);
    expect(find.text('Gecerlilik bitisi'), findsOneWidget);
    expect(find.text('Takip gunu'), findsOneWidget);
  });

  testWidgets('olayi olmayan gune tiklanamaz', (tester) async {
    await pump(tester, const []);

    // 25 Eylul'de hicbir teklif yok; hucre pasif olmali.
    final cell = tester.widget<InkWell>(
      find.byKey(const ValueKey('calendar-day-9-25')),
    );
    expect(cell.onTap, isNull);
  });

  testWidgets('gune tiklayinca o gunun teklifleri listelenir', (tester) async {
    // 1 Eylul + 15 gun = 16 Eylul gecerlilik bitisi.
    await pump(tester, [
      _quote(id: 'a', createdAt: DateTime(2026, 9, 1), company: 'ALFA LTD'),
    ]);

    // Detay acilmadan once firma adi gorunmemeli.
    expect(find.text('ALFA LTD'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('calendar-day-9-16')));
    await tester.pumpAndSettle();

    expect(find.text('ALFA LTD'), findsOneWidget);
    expect(find.text('Gecerlilik'), findsOneWidget);
  });

  testWidgets('detaydaki teklife tiklayinca geri bildirilir', (tester) async {
    Quote? tapped;
    await pump(
      tester,
      [_quote(id: 'a', createdAt: DateTime(2026, 9, 1), company: 'ALFA LTD')],
      onTap: (q) => tapped = q,
    );

    await tester.tap(find.byKey(const ValueKey('calendar-day-9-16')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ALFA LTD'));
    await tester.pumpAndSettle();

    expect(tapped?.id, 'a');
  });

  testWidgets('ay degistirilebilir', (tester) async {
    await pump(tester, const []);

    await tester.tap(find.byKey(const ValueKey('calendar-next-month')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ekim'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-prev-month')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('calendar-prev-month')));
    await tester.pumpAndSettle();
    expect(find.textContaining('Ağustos'), findsOneWidget);
  });

  testWidgets('gonderilmis teklif hem takip hem gecerlilik uretir', (
    tester,
  ) async {
    // 5 Eylul gonderim: takip 8 Eylul, gecerlilik 20 Eylul.
    await pump(tester, [
      _quote(
        id: 'b',
        status: QuoteStatus.sent,
        createdAt: DateTime(2026, 9, 1),
        emailSentAt: DateTime(2026, 9, 5),
        company: 'BETA AS',
      ),
    ]);

    await tester.tap(find.byKey(const ValueKey('calendar-day-9-8')));
    await tester.pumpAndSettle();
    expect(find.text('Takip'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('calendar-day-9-20')));
    await tester.pumpAndSettle();
    expect(find.text('Gecerlilik'), findsOneWidget);
  });
}
