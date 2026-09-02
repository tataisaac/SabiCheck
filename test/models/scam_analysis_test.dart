import 'package:flutter_test/flutter_test.dart';
import 'package:sabicheck/models/analysis_record.dart';
import 'package:sabicheck/models/scam_analysis.dart';

void main() {
  group('ScamAnalysis.fromJson', () {
    final json = <String, dynamic>{
      'riskLevel': 'High',
      'confidenceScore': 93,
      'category': 'Mobile Money Scam',
      'summary': 'Asks for PIN.',
      'explanation': 'Details.',
      'recommendedActions': ['Block.', 'Report.'],
    };

    test('parses the backend contract', () {
      final a = ScamAnalysis.fromJson(json);
      expect(a.riskLevel, RiskLevel.high);
      expect(a.confidenceScore, 93);
      expect(a.category, 'Mobile Money Scam');
      expect(a.recommendedActions, ['Block.', 'Report.']);
    });

    test('round-trips through toJson', () {
      final a = ScamAnalysis.fromJson(json);
      expect(ScamAnalysis.fromJson(a.toJson()).toJson(), a.toJson());
    });

    test('tolerates sloppy risk casing and numeric strings', () {
      final a = ScamAnalysis.fromJson({...json, 'riskLevel': 'medium', 'confidenceScore': '87.6'});
      expect(a.riskLevel, RiskLevel.medium);
      expect(a.confidenceScore, 87);
    });

    test('clamps confidence into 0..100', () {
      expect(ScamAnalysis.fromJson({...json, 'confidenceScore': 140}).confidenceScore, 100);
      expect(ScamAnalysis.fromJson({...json, 'confidenceScore': -2}).confidenceScore, 0);
    });

    test('drops blank actions and non-strings', () {
      final a = ScamAnalysis.fromJson({...json, 'recommendedActions': ['A', '', 3, '  ', 'B']});
      expect(a.recommendedActions, ['A', 'B']);
    });

    test('rejects unknown risk levels and missing fields', () {
      expect(() => ScamAnalysis.fromJson({...json, 'riskLevel': 'Critical'}), throwsFormatException);
      expect(() => ScamAnalysis.fromJson({...json, 'summary': ''}), throwsFormatException);
      expect(() => ScamAnalysis.fromJson({...json}..remove('category')), throwsFormatException);
    });
  });

  group('AnalysisResult.fromJson', () {
    test('reads the envelope with defaults', () {
      final r = AnalysisResult.fromJson({
        'riskLevel': 'Low',
        'confidenceScore': 70,
        'category': 'Safe',
        'summary': 's',
        'explanation': 'e',
        'recommendedActions': ['a'],
        'language': 'fr',
        'source': 'cache',
        'analysisId': 'abc',
      });
      expect(r.languageCode, 'fr');
      expect(r.source, AnalysisSource.cache);
      expect(r.analysisId, 'abc');
      expect(r.analysis.riskLevel, RiskLevel.low);
    });

    test('unknown source becomes AnalysisSource.unknown', () {
      final r = AnalysisResult.fromJson({
        'riskLevel': 'Low',
        'confidenceScore': 70,
        'category': 'Safe',
        'summary': 's',
        'explanation': 'e',
        'recommendedActions': ['a'],
        'source': 'martian',
      });
      expect(r.source, AnalysisSource.unknown);
      expect(r.languageCode, 'en');
    });
  });

  group('AnalysisRecord', () {
    final analysis = ScamAnalysis.fromJson({
      'riskLevel': 'High',
      'confidenceScore': 90,
      'category': 'c',
      'summary': 's',
      'explanation': 'e',
      'recommendedActions': ['a'],
    });

    test('round-trips with multiple languages', () {
      final rec = AnalysisRecord(
        id: '1',
        createdAt: DateTime.utc(2026, 9, 2, 12),
        messagePreview: 'hello',
        hadImage: true,
        analyses: {'en': analysis},
      ).withAnalysis('fr', analysis);
      final back = AnalysisRecord.fromJson(rec.toJson());
      expect(back.id, '1');
      expect(back.hadImage, isTrue);
      expect(back.availableLanguages.toSet(), {'en', 'fr'});
      expect(back.analysisFor('fr').riskLevel, RiskLevel.high);
      expect(back.analysisFor('de').riskLevel, RiskLevel.high, reason: 'falls back to any available language');
    });

    test('makePreview collapses whitespace and truncates', () {
      expect(AnalysisRecord.makePreview('  a \n\n b   c '), 'a b c');
      final long = 'x' * 1000;
      final preview = AnalysisRecord.makePreview(long);
      expect(preview.length, AnalysisRecord.previewMaxChars + 1);
      expect(preview.endsWith('…'), isTrue);
    });

    test('rejects records with no analyses', () {
      expect(
        () => AnalysisRecord.fromJson({'id': '1', 'createdAt': '2026-01-01T00:00:00Z', 'analyses': {}}),
        throwsFormatException,
      );
    });
  });
}
