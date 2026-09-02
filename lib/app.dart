import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'config/app_config.dart';
import 'l10n/app_strings.dart';
import 'screens/history_screen.dart';
import 'screens/home_screen.dart';
import 'screens/settings_screen.dart';
import 'services/sabicheck_api.dart';
import 'services/share_receiver.dart';
import 'state/analysis_controller.dart';
import 'state/history_controller.dart';
import 'state/settings_controller.dart';
import 'theme/app_theme.dart';

/// Root widget. Wires controllers → providers → MaterialApp.
///
/// [apiFactory] and [shareReceiver] are injectable so tests (and the web build)
/// can substitute fakes/no-ops without touching the UI.
class SabiCheckApp extends StatefulWidget {
  const SabiCheckApp({
    super.key,
    required this.prefs,
    this.apiFactory,
    this.shareReceiver,
  });

  final SharedPreferences prefs;
  final SabiCheckApi Function(SettingsController settings)? apiFactory;
  final ShareReceiver? shareReceiver;

  @override
  State<SabiCheckApp> createState() => _SabiCheckAppState();
}

class _SabiCheckAppState extends State<SabiCheckApp> {
  late final SettingsController _settings;
  late final HistoryController _history;
  late final AnalysisController _analysis;

  @override
  void initState() {
    super.initState();
    _settings = SettingsController(widget.prefs, deviceLocale: PlatformDispatcher.instance.locale);
    _history = HistoryController(widget.prefs);
    final apiFactory = widget.apiFactory ?? _defaultApiFactory;
    _analysis = AnalysisController(
      apiFactory: () => apiFactory(_settings),
      history: _history,
      shareReceiver: widget.shareReceiver ?? _defaultShareReceiver(),
    );
    _analysis.startShareListener();
  }

  static SabiCheckApi _defaultApiFactory(SettingsController settings) => HttpSabiCheckApi(
        baseUrl: settings.apiBaseUrl,
        appToken: AppConfig.appToken.isEmpty ? null : AppConfig.appToken,
        appVersion: AppConfig.appVersion,
        platform: kIsWeb ? 'web' : defaultTargetPlatform.name,
      );

  static ShareReceiver _defaultShareReceiver() {
    if (kIsWeb) return const NoopShareReceiver();
    if (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS) {
      return PlatformShareReceiver();
    }
    return const NoopShareReceiver();
  }

  @override
  void dispose() {
    _analysis.dispose();
    _history.dispose();
    _settings.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<SettingsController>.value(value: _settings),
        ChangeNotifierProvider<HistoryController>.value(value: _history),
        ChangeNotifierProvider<AnalysisController>.value(value: _analysis),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) => MaterialApp(
          title: 'SabiCheck',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: settings.themeMode,
          locale: settings.language.locale,
          supportedLocales: [for (final l in AppLanguage.values) l.locale],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: const AppShell(),
        ),
      ),
    );
  }
}

/// Bottom navigation between Check / History / Settings.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;
  AnalysisController? _analysis;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final analysis = context.read<AnalysisController>();
    if (_analysis != analysis) {
      _analysis?.lastShared.removeListener(_jumpToHome);
      _analysis = analysis;
      analysis.lastShared.addListener(_jumpToHome);
    }
  }

  /// Content arriving via the share sheet always lands on the Check tab.
  void _jumpToHome() {
    if (_index != 0 && mounted) setState(() => _index = 0);
  }

  @override
  void dispose() {
    _analysis?.lastShared.removeListener(_jumpToHome);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SettingsController>().strings;
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [HomeScreen(), HistoryScreen(), SettingsScreen()],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.shield_outlined), selectedIcon: const Icon(Icons.shield_rounded), label: s.appName),
          NavigationDestination(icon: const Icon(Icons.history_rounded), label: s.history),
          NavigationDestination(icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings_rounded), label: s.settings),
        ],
      ),
    );
  }
}
