/// Risk verdict. Wire values are frozen ("Low" | "Medium" | "High").
enum RiskLevel {
  low('Low'),
  medium('Medium'),
  high('High');

  const RiskLevel(this.wireValue);

  final String wireValue;

  static RiskLevel fromWire(Object? value) {
    final v = (value as String?)?.trim().toLowerCase();
    return switch (v) {
      'low' => RiskLevel.low,
      'medium' => RiskLevel.medium,
      'high' => RiskLevel.high,
      _ => throw FormatException('Unknown riskLevel: $value'),
    };
  }
}

/// Where a verdict came from (backend `source` field).
enum AnalysisSource {
  gemini,
  mock,
  cache,
  unknown;

  static AnalysisSource fromWire(Object? value) => switch (value) {
        'gemini' => AnalysisSource.gemini,
        'mock' => AnalysisSource.mock,
        'cache' => AnalysisSource.cache,
        _ => AnalysisSource.unknown,
      };
}

/// The core verdict — identical field names to SABICHECK_SPEC.md §5.1 and the backend.
class ScamAnalysis {
  const ScamAnalysis({
    required this.riskLevel,
    required this.confidenceScore,
    required this.category,
    required this.summary,
    required this.explanation,
    required this.recommendedActions,
  });

  factory ScamAnalysis.fromJson(Map<String, dynamic> json) {
    final actions = json['recommendedActions'];
    return ScamAnalysis(
      riskLevel: RiskLevel.fromWire(json['riskLevel']),
      confidenceScore: _toInt(json['confidenceScore']).clamp(0, 100),
      category: _reqString(json, 'category'),
      summary: _reqString(json, 'summary'),
      explanation: _reqString(json, 'explanation'),
      recommendedActions: actions is List
          ? actions.whereType<String>().where((a) => a.trim().isNotEmpty).toList(growable: false)
          : const <String>[],
    );
  }

  final RiskLevel riskLevel;
  final int confidenceScore;
  final String category;
  final String summary;
  final String explanation;
  final List<String> recommendedActions;

  Map<String, dynamic> toJson() => {
        'riskLevel': riskLevel.wireValue,
        'confidenceScore': confidenceScore,
        'category': category,
        'summary': summary,
        'explanation': explanation,
        'recommendedActions': recommendedActions,
      };

  static int _toInt(Object? v) {
    if (v is int) return v;
    if (v is num) return v.round();
    if (v is String) return int.tryParse(v) ?? (double.tryParse(v)?.round() ?? 0);
    return 0;
  }

  static String _reqString(Map<String, dynamic> json, String key) {
    final v = json[key];
    if (v is String && v.trim().isNotEmpty) return v.trim();
    throw FormatException('Missing or empty "$key" in analysis');
  }
}

/// A verdict as returned by `POST /v1/analyze` (analysis + envelope metadata).
class AnalysisResult {
  const AnalysisResult({
    required this.analysis,
    required this.languageCode,
    required this.source,
    required this.analysisId,
  });

  factory AnalysisResult.fromJson(Map<String, dynamic> json) => AnalysisResult(
        analysis: ScamAnalysis.fromJson(json),
        languageCode: (json['language'] as String?) ?? 'en',
        source: AnalysisSource.fromWire(json['source']),
        analysisId: (json['analysisId'] as String?) ?? '',
      );

  final ScamAnalysis analysis;
  final String languageCode;
  final AnalysisSource source;
  final String analysisId;
}
