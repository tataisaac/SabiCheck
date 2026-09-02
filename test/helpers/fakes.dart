import 'dart:async';

import 'package:sabicheck/models/scam_analysis.dart';
import 'package:sabicheck/services/sabicheck_api.dart';
import 'package:sabicheck/services/share_receiver.dart';

const highRisk = ScamAnalysis(
  riskLevel: RiskLevel.high,
  confidenceScore: 93,
  category: 'Mobile Money Scam',
  summary: 'Asks for your PIN and an activation fee.',
  explanation: 'Legitimate providers never ask for your PIN. The urgency and fee are classic signs.',
  recommendedActions: ['Do not send money or share your PIN.', 'Block and report the sender.'],
);

const lowRisk = ScamAnalysis(
  riskLevel: RiskLevel.low,
  confidenceScore: 78,
  category: 'Safe',
  summary: 'Looks like a normal message.',
  explanation: 'No scam indicators.',
  recommendedActions: ['Stay alert.'],
);

/// Scriptable API double. Records calls; returns queued results or throws queued errors.
class FakeApi implements SabiCheckApi {
  final List<({String message, String language, bool hasImage})> analyzeCalls = [];
  final List<({ScamAnalysis analysis, String language})> translateCalls = [];

  ScamAnalysis nextAnalysis = highRisk;
  AnalysisSource nextSource = AnalysisSource.gemini;
  Object? nextAnalyzeError;
  Object? nextTranslateError;

  /// If set, analyze() waits for this completer (lets tests observe the busy state).
  Completer<void>? gate;

  @override
  Future<AnalysisResult> analyze({required String message, required String languageCode, ImagePayload? image}) async {
    analyzeCalls.add((message: message, language: languageCode, hasImage: image != null));
    if (gate != null) await gate!.future;
    final err = nextAnalyzeError;
    if (err != null) {
      nextAnalyzeError = null;
      throw err;
    }
    return AnalysisResult(
      analysis: nextAnalysis,
      languageCode: languageCode,
      source: nextSource,
      analysisId: 'id-${analyzeCalls.length}',
    );
  }

  @override
  Future<ScamAnalysis> translate({required ScamAnalysis analysis, required String languageCode}) async {
    translateCalls.add((analysis: analysis, language: languageCode));
    final err = nextTranslateError;
    if (err != null) {
      nextTranslateError = null;
      throw err;
    }
    return ScamAnalysis(
      riskLevel: analysis.riskLevel,
      confidenceScore: analysis.confidenceScore,
      category: '[${languageCode.toUpperCase()}] ${analysis.category}',
      summary: '[${languageCode.toUpperCase()}] ${analysis.summary}',
      explanation: '[${languageCode.toUpperCase()}] ${analysis.explanation}',
      recommendedActions: analysis.recommendedActions.map((a) => '[${languageCode.toUpperCase()}] $a').toList(),
    );
  }
}

/// Share receiver whose content tests can push manually.
class FakeShareReceiver implements ShareReceiver {
  FakeShareReceiver({this.initial});

  SharedContent? initial;
  final _controller = StreamController<SharedContent>.broadcast();
  int resetCalls = 0;

  void push(SharedContent content) => _controller.add(content);

  @override
  Future<SharedContent?> initialContent() async => initial;

  @override
  Stream<SharedContent> get stream => _controller.stream;

  @override
  Future<void> reset() async => resetCalls++;

  Future<void> close() => _controller.close();
}
