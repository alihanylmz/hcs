class AppConfig {
  const AppConfig._();

  static const String _supabaseUrl =
      String.fromEnvironment('SUPABASE_URL');
  static const String _supabaseAnonKey =
      String.fromEnvironment('SUPABASE_ANON_KEY');
  static const String _legacySupabaseKey =
      String.fromEnvironment('SUPABASE_KEY');
  static const String _configuredOneSignalAppId =
      String.fromEnvironment('ONESIGNAL_APP_ID');
  static const bool isFlutterTest = bool.fromEnvironment('FLUTTER_TEST');

  static const String _defaultOneSignalAppId =
      'faeed989-8a81-4fe0-9c73-2eb9ed2144a7';

  static String get supabaseUrl => _supabaseUrl;

  static String get supabaseAnonKey {
    if (_supabaseAnonKey.isNotEmpty) {
      return _supabaseAnonKey;
    }
    return _legacySupabaseKey;
  }

  static String get oneSignalAppId {
    if (_configuredOneSignalAppId.isNotEmpty) {
      return _configuredOneSignalAppId;
    }
    return _defaultOneSignalAppId;
  }

  static bool get hasSupabaseConfig =>
      supabaseUrl.isNotEmpty && supabaseAnonKey.isNotEmpty;

  static bool get hasOneSignalConfig => oneSignalAppId.isNotEmpty;

  static bool get shouldRunStartupChecks => !isFlutterTest;

  static List<String> get missingRequiredKeys {
    final missing = <String>[];

    if (supabaseUrl.isEmpty) {
      missing.add('SUPABASE_URL');
    }

    if (supabaseAnonKey.isEmpty) {
      missing.add('SUPABASE_ANON_KEY');
    }

    return missing;
  }
}
