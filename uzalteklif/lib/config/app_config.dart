class AppConfig {
  static const supabaseUrl = String.fromEnvironment('SUPABASE_URL');
  static const supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY');
  static const ratesRefreshMinutes = 10;

  /// PDF'lerdeki QR kodun ve kisa linkin acacagi web hedefinin kok adresi.
  ///
  /// Teklif basina uretilen `slug` bu kokun sonuna eklenir, nihai link
  /// `$publicQuoteBaseUrl/$slug` seklinde olusur. Dagitim asamasinda
  /// `--dart-define=PUBLIC_QUOTE_BASE_URL=...` ile degistirilebilir; sondaki
  /// `/` karakteri kaldirilir.
  static const String publicQuoteBaseUrl = String.fromEnvironment(
    'PUBLIC_QUOTE_BASE_URL',
    defaultValue: 'https://uzalteknik.com/t',
  );

  static String get normalizedPublicQuoteBaseUrl {
    final trimmed = publicQuoteBaseUrl.trim();
    if (trimmed.isEmpty) return '';
    return trimmed.endsWith('/')
        ? trimmed.substring(0, trimmed.length - 1)
        : trimmed;
  }

  static bool get hasSupabase =>
      supabaseUrl.trim().isNotEmpty && supabaseAnonKey.trim().isNotEmpty;

  /// GitHub `sahip/repo` (ornek: `uzalteknik/uzalteklif`). Bos ise uygulama
  /// acilisinda GitHub Releases uzerinden otomatik guncelleme kontrolu yapilmaz.
  ///
  /// Yerel: `--dart-define=UPDATE_GITHUB_REPO=owner/repo` veya
  /// `config/supabase.local.json` icine ayni anahtari ekleyin.
  static const String updateGithubRepo = String.fromEnvironment(
    'UPDATE_GITHUB_REPO',
    defaultValue: '',
  );

  /// Bos degilse ve `owner/repo` bicimindeyse GitHub guncelleme kontrolu aciktir.
  static bool get updateCheckEnabled {
    final raw = updateGithubRepo.trim();
    if (raw.isEmpty) return false;
    final parts = raw.split('/');
    return parts.length == 2 &&
        parts[0].trim().isNotEmpty &&
        parts[1].trim().isNotEmpty;
  }

  static (String owner, String repo)? get updateGithubOwnerRepo {
    if (!updateCheckEnabled) return null;
    final parts = updateGithubRepo.trim().split('/');
    return (parts[0].trim(), parts[1].trim());
  }
}
