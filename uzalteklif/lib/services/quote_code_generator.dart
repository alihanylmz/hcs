import 'dart:math';

/// Teklif numarasi: `GAYYYYHHmm`.
///
/// Ornek: `1720260004` => 1.7.2026 00:04.
class QuoteCodeGenerator {
  QuoteCodeGenerator._();

  /// `GAYYYYHHmm`
  static final RegExp pattern = RegExp(r'^UZ-\d{6}-\d{6}$');

  /// Paylasim tokeninde kullanilan alfabe. Karistirilan karakterler (O/0, I/1,
  /// vb.) ve majiskul formlar disaridi; QR okutma sonrasi elle yazmak gerekirse
  /// hata riskini azaltmak icin `base32` benzeri okunur alfabe secildi.
  static const _shareTokenAlphabet = 'abcdefghjkmnpqrstuvwxyz23456789';

  /// Uretilecek paylasim tokeninin karakter sayisi. 4 karakter 31 alfabeyle
  /// ~923k kombinasyon verir; teklif kodu zaten saniye cozunurlugunde
  /// benzersiz oldugu icin tahmin edilemez bir "sir" parcasi olarak yeterli.
  static const int shareTokenLength = 4;

  static final Random _secureRandom = Random.secure();

  static String buildCode({required DateTime timestamp}) {
    final yy = (timestamp.year % 100).toString().padLeft(2, '0');
    final month = timestamp.month.toString().padLeft(2, '0');
    final day = timestamp.day.toString().padLeft(2, '0');
    final hh = timestamp.hour.toString().padLeft(2, '0');
    final min = timestamp.minute.toString().padLeft(2, '0');
    final sec = timestamp.second.toString().padLeft(2, '0');
    return 'UZ-$yy$month$day-$hh$min$sec';
  }

  /// Teklifin herkese acik linkinde kullanilan kisa ve tahmin edilemez parcayi
  /// uretir. Cagri her seferinde benzersiz (kriptografik guvenli) deger uretir.
  static String buildShareToken() {
    final buffer = StringBuffer();
    for (var i = 0; i < shareTokenLength; i++) {
      buffer.write(
        _shareTokenAlphabet[_secureRandom.nextInt(_shareTokenAlphabet.length)],
      );
    }
    return buffer.toString();
  }
}
