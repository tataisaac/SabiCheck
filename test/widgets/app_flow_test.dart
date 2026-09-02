import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sabicheck/app.dart';
import 'package:sabicheck/l10n/app_strings.dart';
import 'package:sabicheck/services/sabicheck_api.dart';
import 'package:sabicheck/services/share_receiver.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fakes.dart';

Future<void> pumpApp(WidgetTester tester, {required FakeApi api, FakeShareReceiver? share, Map<String, Object> prefs = const {}}) async {
  SharedPreferences.setMockInitialValues(prefs);
  final p = await SharedPreferences.getInstance();
  await tester.pumpWidget(SabiCheckApp(prefs: p, apiFactory: (_) => api, shareReceiver: share ?? FakeShareReceiver()));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('renders the awaiting state in English by default', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpApp(tester, api: FakeApi(), prefs: {'settings.language': 'en'});
    expect(find.byKey(const Key('output-awaiting')), findsOneWidget);
    expect(find.text(AppStrings.en.awaitingTitle), findsOneWidget);
    expect(find.byKey(const Key('analyze-button')), findsOneWidget);
  });

  testWidgets('typing + Check message → verdict card with risk badge and history entry', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final api = FakeApi();
    await pumpApp(tester, api: api, prefs: {'settings.language': 'en'});

    await tester.enterText(find.byKey(const Key('message-input')), 'Send your MoMo PIN to claim 500,000 FCFA');
    await tester.pump();
    await tester.tap(find.byKey(const Key('analyze-button')));
    await tester.pumpAndSettle();

    expect(api.analyzeCalls.single.language, 'en');
    expect(find.byKey(const Key('analysis-card')), findsOneWidget);
    expect(find.byKey(const Key('analysis-category')), findsOneWidget);
    expect(find.text(highRisk.category), findsOneWidget);
    expect(find.textContaining('93%'), findsWidgets);

    // Explanation is collapsed until "Read detailed analysis".
    expect(find.byKey(const Key('analysis-explanation')), findsNothing);
    await tester.tap(find.byKey(const Key('analysis-toggle-details')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('analysis-explanation')), findsOneWidget);

    // History tab shows the saved check.
    await tester.tap(find.text(AppStrings.en.history));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('history-list')), findsOneWidget);
    expect(find.text(highRisk.category), findsOneWidget);
  });

  testWidgets('empty input shows the inline error and never calls the API', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final api = FakeApi();
    await pumpApp(tester, api: api, prefs: {'settings.language': 'en'});
    await tester.tap(find.byKey(const Key('analyze-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('error-banner')), findsOneWidget);
    expect(find.text(AppStrings.en.errorEmptyInput), findsOneWidget);
    expect(api.analyzeCalls, isEmpty);
  });

  testWidgets('API failure shows a friendly message; retry succeeds', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final api = FakeApi()..nextAnalyzeError = const ApiException(ApiErrorCode.network, 'down');
    await pumpApp(tester, api: api, prefs: {'settings.language': 'en'});
    await tester.enterText(find.byKey(const Key('message-input')), 'hello');
    await tester.tap(find.byKey(const Key('analyze-button')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.en.errorNetwork), findsOneWidget);
    expect(find.byKey(const Key('analysis-card')), findsNothing);

    await tester.tap(find.byKey(const Key('analyze-button')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('analysis-card')), findsOneWidget);
    expect(find.byKey(const Key('error-banner')), findsNothing);
  });

  testWidgets('switching to FR translates the visible verdict and relabels the UI', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final api = FakeApi();
    await pumpApp(tester, api: api, prefs: {'settings.language': 'en'});
    await tester.enterText(find.byKey(const Key('message-input')), 'Send PIN');
    await tester.tap(find.byKey(const Key('analyze-button')));
    await tester.pumpAndSettle();

    await tester.tap(find.descendant(of: find.byKey(const Key('language-toggle')), matching: find.text('FR')));
    await tester.pumpAndSettle();

    expect(api.translateCalls.single.language, 'fr');
    expect(find.text('[FR] ${highRisk.category}'), findsOneWidget);
    expect(find.text(AppStrings.fr.analyze), findsOneWidget);
    expect(find.text(AppStrings.fr.threatAnalysis.toUpperCase()), findsOneWidget);
    // The user's input is untouched.
    expect(find.text('Send PIN'), findsOneWidget);
  });

  testWidgets('content shared into the app lands in the input and shows a snackbar', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final share = FakeShareReceiver(initial: const SharedContent(text: 'You have won a prize!'));
    await pumpApp(tester, api: FakeApi(), share: share, prefs: {'settings.language': 'en'});
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('You have won a prize!'), findsOneWidget);
    expect(find.text(AppStrings.en.sharedContentReceived), findsOneWidget);
    expect(share.resetCalls, 1);
    await share.close();
  });

  testWidgets('settings: language radio and API URL field persist', (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await pumpApp(tester, api: FakeApi(), prefs: {'settings.language': 'en'});
    await tester.tap(find.text(AppStrings.en.settings));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('language-fr')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.fr.settings), findsWidgets);

    await tester.enterText(find.byKey(const Key('api-url-field')), 'https://api.sabicheck.app');
    await tester.tap(find.byKey(const Key('api-url-save')));
    await tester.pumpAndSettle();
    expect(find.text(AppStrings.fr.saved), findsOneWidget);
    expect(find.byKey(const Key('api-url-reset')), findsOneWidget);

    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('settings.language'), 'fr');
    expect(prefs.getString('settings.apiBaseUrl'), 'https://api.sabicheck.app');
  });
}
