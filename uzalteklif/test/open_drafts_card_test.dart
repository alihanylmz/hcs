import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'package:uzalteklif/models/quote.dart';
import 'package:uzalteklif/widgets/open_drafts_card.dart';

Quote _quote({
  required String id,
  QuoteStatus status = QuoteStatus.draft,
  DateTime? createdAt,
  String company = 'Firma',
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
    int maxItems = 6,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: OpenDraftsCard(
              quotes: quotes,
              onQuoteTap: onTap ?? (_) {},
              maxItems: maxItems,
              today: DateTime(2026, 9, 20),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('yalnizca taslak durumundaki teklifleri listeler', (
    tester,
  ) async {
    await pump(tester, [
      _quote(id: 'a', company: 'TASLAK FIRMA'),
      _quote(id: 'b', status: QuoteStatus.sent, company: 'GONDERILMIS FIRMA'),
      _quote(id: 'c', status: QuoteStatus.won, company: 'KAZANILMIS FIRMA'),
    ]);

    expect(find.text('TASLAK FIRMA'), findsOneWidget);
    expect(find.text('GONDERILMIS FIRMA'), findsNothing);
    expect(find.text('KAZANILMIS FIRMA'), findsNothing);
  });

  testWidgets('en eski taslak en ustte siralanir', (tester) async {
    await pump(tester, [
      _quote(id: 'yeni', createdAt: DateTime(2026, 9, 18), company: 'YENI'),
      _quote(id: 'eski', createdAt: DateTime(2026, 9, 1), company: 'ESKI'),
    ]);

    final eski = tester.getTopLeft(find.text('ESKI'));
    final yeni = tester.getTopLeft(find.text('YENI'));
    expect(
      eski.dy,
      lessThan(yeni.dy),
      reason: 'bekleyen en eski is once gorulmeli',
    );
  });

  testWidgets('bekleme suresi gosterilir', (tester) async {
    await pump(tester, [
      _quote(id: 'a', createdAt: DateTime(2026, 9, 20)),
      _quote(id: 'b', createdAt: DateTime(2026, 9, 19)),
      _quote(id: 'c', createdAt: DateTime(2026, 9, 8)),
    ]);

    expect(find.text('bugun olusturuldu'), findsOneWidget);
    expect(find.text('dun olusturuldu'), findsOneWidget);
    expect(find.text('12 gundur bekliyor'), findsOneWidget);
  });

  testWidgets('taslak yoksa bilgilendirme gosterilir', (tester) async {
    await pump(tester, [_quote(id: 'a', status: QuoteStatus.sent)]);
    expect(find.text('Bekleyen taslak yok.'), findsOneWidget);
  });

  testWidgets('liste sinirlanir ve kalan sayi belirtilir', (tester) async {
    await pump(
      tester,
      [for (var i = 0; i < 9; i++) _quote(id: 'q$i', company: 'F$i')],
      maxItems: 3,
    );

    expect(find.byType(InkWell), findsNWidgets(3));
    expect(find.text('ve 6 taslak daha'), findsOneWidget);
  });

  testWidgets('satira tiklayinca teklif geri bildirilir', (tester) async {
    Quote? tapped;
    await pump(
      tester,
      [_quote(id: 'a', company: 'ALFA')],
      onTap: (q) => tapped = q,
    );

    await tester.tap(find.byKey(const ValueKey('draft-row-a')));
    await tester.pumpAndSettle();

    expect(tapped?.id, 'a');
  });
}
