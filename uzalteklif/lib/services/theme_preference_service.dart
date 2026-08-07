import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemePreferenceService extends ChangeNotifier {
  ThemePreferenceService._(this._prefs) {
    _mode = _parse(_prefs.getString(_key));
  }

  static const _key = 'app_theme_mode';

  final SharedPreferences _prefs;
  late ThemeMode _mode;

  ThemeMode get mode => _mode;

  static Future<ThemePreferenceService> create() async {
    final prefs = await SharedPreferences.getInstance();
    return ThemePreferenceService._(prefs);
  }

  Future<void> setMode(ThemeMode mode) async {
    if (_mode == mode) return;
    _mode = mode;
    await _prefs.setString(_key, _stringify(mode));
    notifyListeners();
  }

  static ThemeMode _parse(String? raw) {
    switch (raw) {
      case 'light':
        return ThemeMode.light;
      case 'dark':
        return ThemeMode.dark;
      default:
        return ThemeMode.system;
    }
  }

  static String _stringify(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.light:
        return 'light';
      case ThemeMode.dark:
        return 'dark';
      case ThemeMode.system:
        return 'system';
    }
  }
}
