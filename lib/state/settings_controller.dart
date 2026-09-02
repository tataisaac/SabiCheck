import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../l10n/app_strings.dart';

/// User preferences persisted with SharedPreferences.
class SettingsController extends ChangeNotifier {
  SettingsController(this._prefs, {Locale? deviceLocale})
      : _language = _prefs.getString(_kLanguage) != null
            ? AppLanguage.fromCode(_prefs.getString(_kLanguage))
            : AppLanguage.fromLocale(deviceLocale),
        _themeMode = _themeFromString(_prefs.getString(_kTheme)),
        _apiBaseUrl = _prefs.getString(_kApiUrl) ?? AppConfig.defaultApiBaseUrl;

  static const _kLanguage = 'settings.language';
  static const _kTheme = 'settings.theme';
  static const _kApiUrl = 'settings.apiBaseUrl';

  final SharedPreferences _prefs;

  AppLanguage _language;
  ThemeMode _themeMode;
  String _apiBaseUrl;

  AppLanguage get language => _language;
  AppStrings get strings => AppStrings.of(_language);
  ThemeMode get themeMode => _themeMode;
  String get apiBaseUrl => _apiBaseUrl;
  bool get isCustomApiUrl => _apiBaseUrl != AppConfig.defaultApiBaseUrl;

  Future<void> setLanguage(AppLanguage language) async {
    if (language == _language) return;
    _language = language;
    notifyListeners();
    await _prefs.setString(_kLanguage, language.code);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    if (mode == _themeMode) return;
    _themeMode = mode;
    notifyListeners();
    await _prefs.setString(_kTheme, mode.name);
  }

  /// Returns null on success or a validation problem key (caller maps to copy).
  Future<String?> setApiBaseUrl(String url) async {
    final trimmed = url.trim();
    if (trimmed.isEmpty) {
      return resetApiBaseUrl();
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty) {
      return 'invalid';
    }
    _apiBaseUrl = trimmed;
    notifyListeners();
    await _prefs.setString(_kApiUrl, trimmed);
    return null;
  }

  Future<String?> resetApiBaseUrl() async {
    _apiBaseUrl = AppConfig.defaultApiBaseUrl;
    notifyListeners();
    await _prefs.remove(_kApiUrl);
    return null;
  }

  static ThemeMode _themeFromString(String? v) => switch (v) {
        'light' => ThemeMode.light,
        'dark' => ThemeMode.dark,
        _ => ThemeMode.system,
      };
}
