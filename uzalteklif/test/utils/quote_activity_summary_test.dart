import 'package:flutter_test/flutter_test.dart';
import 'package:uzalteklif/models/quote.dart';
import 'package:uzalteklif/utils/quote_activity_summary.dart';

final _now = DateTime(2026, 9, 8, 12);

Quote _quote({
  QuoteStatus status = QuoteStatus.draft,
  DateTime? createdAt,
  DateTime? emailSentAt,
  DateTime? emailViewedAt,
}) {
  return Quote(
    id: 'q',
    code: 'UZ-1',
    customerName: 'Yetkili',
    customerCompany: 'Firma',
    title: 'Konu',
    note: '',
    createdAt: createdAt ?? _now,
    displayUnit: 'TL',
    marketSnapshot: const [],
    status: status,
    emailSentAt: emailSentAt,
    emailViewedAt: emailViewedAt,
    items: const [],
    documentProfile: const QuoteDocumentProfile(
      companyName: '', companyTagline: '', companyPhone: '', companyEmail: '',
      companyWebsite: '', companyAddress: '', preparedByName: '',
      preparedByTitle: '', preparedByPhone: '', preparedByEmail: '',
      customerContactTitle: '', customerPhone: '', customerEmail: '',
      validityText: '', paymentTerms: '', deliveryTerms: '',
    ),
  );
}

void main() {
  group('summarizeQuoteActivity', () {
    test('goruldu bilgisi gonderildiden once gelir', () {
      // En yeni bilgi gosterilmeli: musteri baktiysa satirda o yazmali.
      final s = summarizeQuoteActivity(
        _quote(
          status: QuoteStatus.sent,
          emailSentAt: _now.subtract(const Duration(days: 5)),
          emailViewedAt: _now.subtract(const Duration(days: 2)),
        ),
        now: _now,
      );
      expect(s.label, 'Görüldü · 2 gün önce');
    });

    test('gonderildi ama goruldu yoksa gonderim tarihi gosterilir', () {
      final s = summarizeQuoteActivity(
        _quote(
          status: QuoteStatus.sent,
          emailSentAt: _now.subtract(const Duration(days: 1)),
        ),
        now: _now,
      );
      expect(s.label, 'Gönderildi · dün');
    });

    test('hic gonderilmemis taslak yasini gosterir', () {
      final s = summarizeQuoteActivity(
        _quote(createdAt: _now.subtract(const Duration(days: 12))),
        now: _now,
      );
      expect(s.label, 'Taslak · 12 gün önce');
    });

    test('3 gunden uzun cevapsiz gonderim bayat sayilir', () {
      final s = summarizeQuoteActivity(
        _quote(
          status: QuoteStatus.sent,
          emailSentAt: _now.subtract(const Duration(days: 4)),
        ),
        now: _now,
      );
      expect(s.isStale, isTrue);
    });

    test('yeni gonderim bayat sayilmaz', () {
      final s = summarizeQuoteActivity(
        _quote(
          status: QuoteStatus.sent,
          emailSentAt: _now.subtract(const Duration(days: 1)),
        ),
        now: _now,
      );
      expect(s.isStale, isFalse);
    });

    test('kapanmis teklif bayat sayilmaz', () {
      // Kazanilan/kaybedilen teklif takip edilmez; uyari vermemeli.
      for (final status in [
        QuoteStatus.won,
        QuoteStatus.lost,
        QuoteStatus.cancelled,
        QuoteStatus.expired,
      ]) {
        final s = summarizeQuoteActivity(
          _quote(
            status: status,
            emailSentAt: _now.subtract(const Duration(days: 90)),
          ),
          now: _now,
        );
        expect(s.isStale, isFalse, reason: '$status bayat sayilmamali');
      }
    });

    test('bir haftadan eski taslak bayat sayilir', () {
      final s = summarizeQuoteActivity(
        _quote(createdAt: _now.subtract(const Duration(days: 8))),
        now: _now,
      );
      expect(s.isStale, isTrue);
    });

    test('ileri tarihli kayit negatif gun uretmez', () {
      final s = summarizeQuoteActivity(
        _quote(createdAt: _now.add(const Duration(days: 3))),
        now: _now,
      );
      expect(s.label, 'Taslak · bugün');
    });

    test('uzun sureler ay ve yil olarak yazilir', () {
      expect(
        summarizeQuoteActivity(
          _quote(createdAt: _now.subtract(const Duration(days: 65))),
          now: _now,
        ).label,
        'Taslak · 2 ay önce',
      );
      expect(
        summarizeQuoteActivity(
          _quote(createdAt: _now.subtract(const Duration(days: 400))),
          now: _now,
        ).label,
        'Taslak · 1 yıl önce',
      );
    });
  });
}
