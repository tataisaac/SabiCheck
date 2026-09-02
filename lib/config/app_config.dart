import 'package:flutter/foundation.dart';

/// Build-time configuration. Override with `--dart-define`, e.g.
///
///   flutter run --dart-define=SABICHECK_API_URL=http://192.168.1.20:8080
///   flutter build apk --dart-define=SABICHECK_API_URL=https://api.sabicheck.app
///
/// The API URL can also be changed at runtime from Settings → Developer.
class AppConfig {
  AppConfig._();

  /// Backend base URL. Default targets the Android emulator's host loopback
  /// in debug and a placeholder production host in release — set the real one
  /// with --dart-define before shipping.
  static const String defaultApiBaseUrl = String.fromEnvironment(
    'SABICHECK_API_URL',
    defaultValue: kReleaseMode ? 'https://api.sabicheck.example' : 'http://10.0.2.2:8080',
  );

  /// Optional shared secret matching the backend's SABICHECK_APP_TOKEN.
  static const String appToken = String.fromEnvironment('SABICHECK_APP_TOKEN', defaultValue: '');

  static const String appVersion = '0.1.0';

  /// Client-side guard matching the backend default MAX_IMAGE_BYTES.
  static const int maxImageBytes = 5 * 1024 * 1024;

  /// Longest message we send (backend default MAX_TEXT_CHARS).
  static const int maxTextChars = 8000;

  /// Max saved checks kept in local history.
  static const int maxHistoryEntries = 100;
}
