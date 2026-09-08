import '../models/quote.dart';

/// Bir teklifin son durumunu tek satırda anlatan özet.
class QuoteActivitySummary {
  const QuoteActivitySummary({
    required this.label,
    required this.isStale,
  });

  /// "Gönderildi · 5 gün önce" gibi.
  final String label;

  /// Dikkat çekmesi gereken durumlar: gönderildi ama uzun süredir cevap yok,
  /// ya da uzun süredir taslakta bekliyor.
  final bool isStale;
}

/// Teklifin son anlamlı hareketini ve bayatlık durumunu hesaplar.
///
/// Öncelik sırası en yeni bilgiden eskiye: görüldü > gönderildi > oluşturuldu.
/// Böylece satırda teklifin **şu an nerede olduğu** görünür, sadece ne zaman
/// açıldığı değil.
QuoteActivitySummary summarizeQuoteActivity(Quote quote, {DateTime? now}) {
  final current = now ?? DateTime.now();

  // Kapanmış teklifler takip edilmez; bayat sayılmamalılar.
  final isClosed =
      quote.status == QuoteStatus.won ||
      quote.status == QuoteStatus.lost ||
      quote.status == QuoteStatus.cancelled ||
      quote.status == QuoteStatus.expired;

  if (quote.emailViewedAt != null) {
    final days = _daysSince(quote.emailViewedAt!, current);
    return QuoteActivitySummary(
      label: 'Görüldü · ${_relative(days)}',
      // Müşteri baktı ama dönmediyse takip edilmeli.
      isStale: !isClosed && days >= 3,
    );
  }

  if (quote.emailSentAt != null) {
    final days = _daysSince(quote.emailSentAt!, current);
    return QuoteActivitySummary(
      label: 'Gönderildi · ${_relative(days)}',
      isStale: !isClosed && days >= 3,
    );
  }

  final days = _daysSince(quote.createdAt, current);
  if (quote.status == QuoteStatus.draft) {
    return QuoteActivitySummary(
      label: 'Taslak · ${_relative(days)}',
      // Uzun süredir taslakta duran teklif ya unutulmuş ya da sistem
      // disinda gonderilmis demektir; ikisi de gorulmeli.
      isStale: days >= 7,
    );
  }

  return QuoteActivitySummary(
    label: 'Oluşturuldu · ${_relative(days)}',
    isStale: false,
  );
}

int _daysSince(DateTime past, DateTime now) {
  // Saat farkindan dogan negatif degerleri sifira cekiyoruz; ileri tarihli
  // kayitlar "-3 gun once" gibi anlamsiz metin uretmesin.
  final diff = now.difference(past).inDays;
  return diff < 0 ? 0 : diff;
}

String _relative(int days) {
  if (days == 0) return 'bugün';
  if (days == 1) return 'dün';
  if (days < 30) return '$days gün önce';
  final months = days ~/ 30;
  if (months < 12) return '$months ay önce';
  return '${days ~/ 365} yıl önce';
}
