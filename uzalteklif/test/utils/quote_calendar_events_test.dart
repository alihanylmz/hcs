import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/quote.dart';
import 'package:uzalteklif/utils/quote_calendar_events.dart';

Quote _quote({
  String id = 'q',
  QuoteStatus status = QuoteStatus.draft,
  DateTime? createdAt,
  DateTime? emailSentAt,
  String validityText = '15 gun',
}) {
  return Quote(
    id: id,
    code: 'UZ-$id',
    customerName: 'Yetkili',
    customerCompany: 'Firma',
    title: 'Konu',
    note: '',
    createdAt: createdAt ?? DateTime(2026, 9, 1),
    displayUnit: 'TL',
    marketSnapshot: const [],
    status: status,
    emailSentAt: emailSentAt,
    items: const [],
    documentProfile: QuoteDocumentProfile(
      companyName: '', companyTagline: '', companyPhone: '', companyEmail: '',
      companyWebsite: '', companyAddress: '', preparedByName: '',
      preparedByTitle: '', preparedByPhone: '', preparedByEmail: '',
      customerContactTitle: '', customerPhone: '', customerEmail: '',
      validityText: validityText, paymentTerms: '', deliveryTerms: '',
    ),
  );
}

void main() {
  group('parseValidityDays', () {
    test('gun ifadelerini okur', () {
      expect(parseValidityDays('15 gun'), 15);
      expect(parseValidityDays('15 gün'), 15);
      expect(parseValidityDays('30 GÜN'), 30);
      expect(parseValidityDays('7'), 7);
    });

    test('ay ifadesini gune cevirir', () {
      expect(parseValidityDays('1 ay'), 30);
      expect(parseValidityDays('2 AY'), 60);
    });

    test('cozulemeyen metin null doner', () {
      // Uydurma tarih uretmektense hic olay uretmemek dogru.
      expect(parseValidityDays(''), isNull);
      expect(parseValidityDays('mutabakata gore'), isNull);
      expect(parseValidityDays('0 gun'), isNull);
    });

    test('anlamsiz uzunluktaki deger elenir', () {
      expect(parseValidityDays('99999 gun'), isNull);
    });
  });

  group('buildQuoteCalendarEvents', () {
    test('gecerlilik gonderim tarihinden itibaren hesaplanir', () {
      final events = buildQuoteCalendarEvents([
        _quote(
          status: QuoteStatus.sent,
          createdAt: DateTime(2026, 9, 1),
          emailSentAt: DateTime(2026, 9, 5),
        ),
      ]);
      final expiry = events.firstWhere(
        (e) => e.kind == QuoteCalendarEventKind.expiry,
      );
      // 5 Eylul + 15 gun = 20 Eylul. Olusturma tarihi degil gonderim esas.
      expect(expiry.day, DateTime(2026, 9, 20));
    });

    test('gonderilmemis teklifte olusturma tarihi esas alinir', () {
      final events = buildQuoteCalendarEvents([
        _quote(createdAt: DateTime(2026, 9, 1)),
      ]);
      expect(events, hasLength(1));
      expect(events.first.kind, QuoteCalendarEventKind.expiry);
      expect(events.first.day, DateTime(2026, 9, 16));
    });

    test('takip olayi yalnizca gonderilmis tekliflerde uretilir', () {
      final notSent = buildQuoteCalendarEvents([_quote()]);
      expect(
        notSent.where((e) => e.kind == QuoteCalendarEventKind.followUp),
        isEmpty,
      );

      final sent = buildQuoteCalendarEvents([
        _quote(status: QuoteStatus.sent, emailSentAt: DateTime(2026, 9, 5)),
      ]);
      final follow = sent.firstWhere(
        (e) => e.kind == QuoteCalendarEventKind.followUp,
      );
      expect(follow.day, DateTime(2026, 9, 8));
    });

    test('kapanmis teklifler hic olay uretmez', () {
      for (final status in [
        QuoteStatus.won,
        QuoteStatus.lost,
        QuoteStatus.cancelled,
        QuoteStatus.expired,
      ]) {
        final events = buildQuoteCalendarEvents([
          _quote(status: status, emailSentAt: DateTime(2026, 9, 5)),
        ]);
        expect(events, isEmpty, reason: '$status olay uretmemeli');
      }
    });

    test('gecerlilik cozulemezse o teklif icin olay uretilmez', () {
      final events = buildQuoteCalendarEvents([
        _quote(validityText: 'mutabakata gore'),
      ]);
      expect(events, isEmpty);
    });

    test('olaylar gune gore gruplanir', () {
      final events = buildQuoteCalendarEvents([
        _quote(id: 'a', createdAt: DateTime(2026, 9, 1)),
        _quote(id: 'b', createdAt: DateTime(2026, 9, 1)),
        _quote(id: 'c', createdAt: DateTime(2026, 9, 2)),
      ]);
      final grouped = groupEventsByDay(events);
      expect(grouped[DateTime(2026, 9, 16)], hasLength(2));
      expect(grouped[DateTime(2026, 9, 17)], hasLength(1));
    });
  });
}
