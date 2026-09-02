import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabicheck/config/app_config.dart';
import 'package:sabicheck/l10n/app_strings.dart';
import 'package:sabicheck/models/scam_analysis.dart';
import 'package:sabicheck/services/sabicheck_api.dart';
import 'package:sabicheck/services/share_receiver.dart';
import 'package:sabicheck/state/analysis_controller.dart';
import 'package:sabicheck/state/history_controller.dart';
import 'package:sabicheck/state/settings_controller.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

Future<SharedPreferences> freshPrefs([Map<String, Object> values = const {}]) async {
  SharedPreferences.setMockInitialValues(values);
  return SharedPreferences.getInstance();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('SettingsController', () {
    test('defaults: language from device locale, system theme, default API URL', () async {
      final prefs = await freshPrefs();
      final fr = SettingsController(prefs, deviceLocale: const Locale('fr', 'CM'));
      expect(fr.language, AppLanguage.fr);
      final en = SettingsController(prefs, deviceLocale: const Locale('en', 'NG'));
      expect(en.language, AppLanguage.en);
      expect(en.themeMode, ThemeMode.system);
      expect(en.apiBaseUrl, AppConfig.defaultApiBaseUrl);
      expect(en.isCustomApiUrl, isFalse);
    });

    test('persists language, theme and API URL', () async {
      final prefs = await freshPrefs();
      final c = SettingsController(prefs, deviceLocale: const Locale('en'));
      var notified = 0;
      c.addListener(() => notified++);

      await c.setLanguage(AppLanguage.fr);
      await c.setThemeMode(ThemeMode.dark);
      expect(await c.setApiBaseUrl('https://api.sabicheck.app/'), isNull);
      expect(notified, 3);

      final reloaded = SettingsController(prefs, deviceLocale: const Locale('en'));
      expect(reloaded.language, AppLanguage.fr);
      expect(reloaded.themeMode, ThemeMode.dark);
      expect(reloaded.apiBaseUrl, 'https://api.sabicheck.app/');
      expect(reloaded.isCustomApiUrl, isTrue);
    });

    test('rejects invalid API URLs and resets to default', () async {
      final c = SettingsController(await freshPrefs(), deviceLocale: const Locale('en'));
      expect(await c.setApiBaseUrl('not a url'), 'invalid');
      expect(await c.setApiBaseUrl('ftp://x.y'), 'invalid');
      expect(c.apiBaseUrl, AppConfig.defaultApiBaseUrl);
      expect(await c.setApiBaseUrl('http://192.168.1.20:8080'), isNull);
      expect(await c.setApiBaseUrl('   '), isNull, reason: 'blank resets');
      expect(c.apiBaseUrl, AppConfig.defaultApiBaseUrl);
    });
  });

  group('HistoryController', () {
    test('adds newest-first, persists, and reloads', () async {
      final prefs = await freshPrefs();
      final h = HistoryController(prefs);
      expect(h.isEmpty, isTrue);
      await h.add(message: 'first', hadImage: false, languageCode: 'en', analysis: lowRisk, id: 'a');
      await h.add(message: 'second', hadImage: true, languageCode: 'fr', analysis: highRisk, id: 'b');
      expect(h.records.map((r) => r.id), ['b', 'a']);

      final reloaded = HistoryController(prefs);
      expect(reloaded.records.length, 2);
      expect(reloaded.records.first.hadImage, isTrue);
      expect(reloaded.records.first.analysisFor('fr').riskLevel, RiskLevel.high);
    });

    test('addTranslation attaches a second language; remove and clear work', () async {
      final h = HistoryController(await freshPrefs());
      await h.add(message: 'm', hadImage: false, languageCode: 'en', analysis: highRisk, id: 'x');
      await h.addTranslation('x', 'fr', lowRisk);
      expect(h.byId('x')!.availableLanguages.toSet(), {'en', 'fr'});
      await h.addTranslation('missing', 'fr', lowRisk); // no-op
      await h.remove('x');
      expect(h.isEmpty, isTrue);
      await h.add(message: 'm', hadImage: false, languageCode: 'en', analysis: highRisk);
      await h.clear();
      expect(h.isEmpty, isTrue);
    });

    test('caps the number of records', () async {
      final h = HistoryController(await freshPrefs());
      for (var i = 0; i < AppConfig.maxHistoryEntries + 5; i++) {
        await h.add(message: 'm$i', hadImage: false, languageCode: 'en', analysis: lowRisk, id: 'id$i');
      }
      expect(h.records.length, AppConfig.maxHistoryEntries);
      expect(h.records.first.id, 'id${AppConfig.maxHistoryEntries + 4}');
    });

    test('skips corrupt entries instead of losing everything', () async {
      final prefs = await freshPrefs({
        'history.records.v1':
            '[{"id":"ok","createdAt":"2026-01-01T00:00:00Z","messagePreview":"m","hadImage":false,"analyses":{"en":${_json(lowRisk)}}},{"id":"bad"}, 42]',
      });
      final h = HistoryController(prefs);
      expect(h.records.map((r) => r.id), ['ok']);
    });
  });

  group('AnalysisController', () {
    late FakeApi api;
    late HistoryController history;
    late AnalysisController c;

    setUp(() async {
      api = FakeApi();
      history = HistoryController(await freshPrefs());
      c = AnalysisController(apiFactory: () => api, history: history);
    });

    test('refuses to analyze empty input', () async {
      await c.analyze(AppLanguage.en);
      expect(c.status, AnalysisStatus.error);
      expect(c.error, AnalysisErrorKind.emptyInput);
      expect(api.analyzeCalls, isEmpty);
      c.setMessage('now there is text');
      expect(c.status, AnalysisStatus.idle, reason: 'typing clears the empty-input error');
    });

    test('happy path: analyzing → done, verdict cached per language, history saved', () async {
      c.setMessage('  Send your PIN now  ');
      api.gate = Completer<void>();
      final future = c.analyze(AppLanguage.en);
      expect(c.status, AnalysisStatus.analyzing);
      expect(c.isBusy, isTrue);
      api.gate!.complete();
      await future;

      expect(c.status, AnalysisStatus.done);
      expect(api.analyzeCalls.single.message, 'Send your PIN now', reason: 'trimmed');
      expect(api.analyzeCalls.single.language, 'en');
      expect(c.analysisFor('en')!.riskLevel, RiskLevel.high);
      expect(c.analysisFor('fr'), isNull);
      expect(history.records.single.messagePreview, 'Send your PIN now');
      expect(history.records.single.id, 'id-1', reason: 'uses the server analysisId');
    });

    test('language switch translates the verdict once and never rewrites the input', () async {
      c.setMessage('Envoyez votre PIN');
      await c.analyze(AppLanguage.en);
      await c.ensureTranslation(AppLanguage.fr);
      expect(api.translateCalls.single.language, 'fr');
      expect(c.analysisFor('fr')!.summary, startsWith('[FR] '));
      expect(c.message, 'Envoyez votre PIN', reason: 'the evidence is untouched');
      expect(history.records.single.availableLanguages.toSet(), {'en', 'fr'});

      await c.ensureTranslation(AppLanguage.fr);
      await c.ensureTranslation(AppLanguage.en);
      expect(api.translateCalls.length, 1, reason: 'cached, no second call');
    });

    test('translation failure keeps the verdict and surfaces a transient error', () async {
      c.setMessage('x');
      await c.analyze(AppLanguage.en);
      api.nextTranslateError = const ApiException(ApiErrorCode.rateLimited, 'slow');
      await c.ensureTranslation(AppLanguage.fr);
      expect(c.status, AnalysisStatus.done);
      expect(c.error, AnalysisErrorKind.rateLimited);
      expect(c.analysisFor('en'), isNotNull);
      c.dismissError();
      expect(c.error, isNull);
    });

    test('maps API errors to user-facing kinds', () async {
      final cases = {
        ApiErrorCode.network: AnalysisErrorKind.network,
        ApiErrorCode.timeout: AnalysisErrorKind.timeout,
        ApiErrorCode.upstreamTimeout: AnalysisErrorKind.timeout,
        ApiErrorCode.rateLimited: AnalysisErrorKind.rateLimited,
        ApiErrorCode.unauthorized: AnalysisErrorKind.unauthorized,
        ApiErrorCode.payloadTooLarge: AnalysisErrorKind.payloadTooLarge,
        ApiErrorCode.upstreamError: AnalysisErrorKind.upstream,
        ApiErrorCode.invalidModelOutput: AnalysisErrorKind.upstream,
        ApiErrorCode.internal: AnalysisErrorKind.server,
      };
      for (final entry in cases.entries) {
        c.setMessage('m');
        api.nextAnalyzeError = ApiException(entry.key, 'boom');
        await c.analyze(AppLanguage.en);
        expect(c.status, AnalysisStatus.error, reason: '${entry.key}');
        expect(c.error, entry.value, reason: '${entry.key}');
      }
      expect(history.isEmpty, isTrue, reason: 'failures are not saved');
    });

    test('clearAll discards an in-flight result', () async {
      c.setMessage('m');
      api.gate = Completer<void>();
      final future = c.analyze(AppLanguage.en);
      c.clearAll();
      api.gate!.complete();
      await future;
      expect(c.status, AnalysisStatus.idle);
      expect(c.result, isNull);
      expect(history.isEmpty, isTrue);
    });

    test('share sheet: initial content populates input, resets the plugin, and jumps state', () async {
      final share = FakeShareReceiver(initial: const SharedContent(text: 'Congratulations! You won.'));
      final c2 = AnalysisController(apiFactory: () => api, history: history, shareReceiver: share);
      SharedContent? notified;
      c2.lastShared.addListener(() => notified = c2.lastShared.value);

      await c2.startShareListener();
      expect(c2.message, 'Congratulations! You won.');
      expect(share.resetCalls, 1);
      expect(notified?.text, 'Congratulations! You won.');

      // Warm share replaces the previous result.
      await c2.analyze(AppLanguage.en);
      expect(c2.result, isNotNull);
      share.push(const SharedContent(text: 'second message'));
      await Future<void>.delayed(Duration.zero);
      expect(c2.message, 'second message');
      expect(c2.result, isNull);
      expect(c2.status, AnalysisStatus.idle);
      await share.close();
      c2.dispose();
    });

    test('errorMessageFor has copy for every kind in both languages', () {
      for (final kind in AnalysisErrorKind.values) {
        expect(errorMessageFor(kind, AppStrings.en), isNotEmpty);
        expect(errorMessageFor(kind, AppStrings.fr), isNotEmpty);
        expect(errorMessageFor(kind, AppStrings.en), isNot(errorMessageFor(kind, AppStrings.fr)));
      }
    });
  });
}

String _json(ScamAnalysis a) =>
    '{"riskLevel":"${a.riskLevel.wireValue}","confidenceScore":${a.confidenceScore},"category":"${a.category}","summary":"${a.summary}","explanation":"${a.explanation}","recommendedActions":["${a.recommendedActions.first}"]}';
