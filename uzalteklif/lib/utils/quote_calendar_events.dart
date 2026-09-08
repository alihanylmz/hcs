import '../models/quote.dart';

/// Takvimde gosterilen olay turu.
enum QuoteCalendarEventKind {
  /// Teklifin gecerlilik suresinin doldugu gun.
  expiry,

  /// Gonderimden sonra takip edilmesi onerilen gun.
  followUp,
}

class QuoteCalendarEvent {
  const QuoteCalendarEvent({
    required this.quote,
    required this.kind,
    required this.day,
  });

  final Quote quote;
  final QuoteCalendarEventKind kind;

  /// Saat bilgisi olmadan, yerel gun.
  final DateTime day;
}

/// Teklifin gecerlilik suresini gun olarak cozer.
///
/// `validity_text` serbest metin ("15 gun", "15 gün", "1 ay", "30 GÜN").
/// Icindeki ilk sayiyi alir; metinde "ay" geciyorsa ay olarak yorumlar.
/// Cozulemezse null doner ve cagiran taraf o teklif icin gecerlilik olayi
/// uretmez - uydurma bir tarih gostermektense hic gostermemek dogru.
int? parseValidityDays(String raw) {
  final text = raw.trim().toLowerCase();
  if (text.isEmpty) return null;
  final match = RegExp(r'\d+').firstMatch(text);
  if (match == null) return null;
  final value = int.tryParse(match.group(0)!);
  if (value == null || value <= 0) return null;
  // "ay" ve "month" ay olarak yorumlanir; digerleri gun kabul edilir.
  final isMonth = text.contains('ay') || text.contains('month');
  final days = isMonth ? value * 30 : value;
  // Anlamsiz uzunluktaki degerleri eliyoruz; veri hatasi takvimi bozmasin.
  return days > 3650 ? null : days;
}

/// Takip icin onerilen bekleme suresi. Masam'daki kirmizi alarm kurali da
/// ayni esigi kullaniyor; iki yer ayrisirsa kullanici celiskili bilgi gorur.
const followUpDays = 3;

/// Verilen tekliflerden takvim olaylarini uretir.
///
/// Kapanmis teklifler (kazanildi / kaybedildi / iptal / suresi doldu) hic
/// olay uretmez: onlar icin takip ya da gecerlilik takibi anlamsiz.
List<QuoteCalendarEvent> buildQuoteCalendarEvents(List<Quote> quotes) {
  final events = <QuoteCalendarEvent>[];

  for (final quote in quotes) {
    final isClosed =
        quote.status == QuoteStatus.won ||
        quote.status == QuoteStatus.lost ||
        quote.status == QuoteStatus.cancelled ||
        quote.status == QuoteStatus.expired;
    if (isClosed) continue;

    // Gecerlilik, teklifin muhataba ulastigi andan itibaren islemeli.
    // Henuz gonderilmemisse olusturma tarihi kullanilir.
    final anchor = quote.emailSentAt ?? quote.createdAt;

    final days = parseValidityDays(quote.documentProfile.validityText);
    if (days != null) {
      events.add(
        QuoteCalendarEvent(
          quote: quote,
          kind: QuoteCalendarEventKind.expiry,
          day: _dayOnly(anchor.add(Duration(days: days))),
        ),
      );
    }

    // Takip yalnizca gercekten gonderilmis teklifler icin anlamli.
    if (quote.emailSentAt != null) {
      events.add(
        QuoteCalendarEvent(
          quote: quote,
          kind: QuoteCalendarEventKind.followUp,
          day: _dayOnly(
            quote.emailSentAt!.add(const Duration(days: followUpDays)),
          ),
        ),
      );
    }
  }

  return events;
}

/// Olaylari gune gore gruplar; takvim hucreleri bunu okur.
Map<DateTime, List<QuoteCalendarEvent>> groupEventsByDay(
  List<QuoteCalendarEvent> events,
) {
  final map = <DateTime, List<QuoteCalendarEvent>>{};
  for (final e in events) {
    map.putIfAbsent(e.day, () => []).add(e);
  }
  return map;
}

DateTime _dayOnly(DateTime value) {
  final local = value.toLocal();
  return DateTime(local.year, local.month, local.day);
}
