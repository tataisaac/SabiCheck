import 'scam_analysis.dart';

/// A saved check in local history. Screenshots are deliberately NOT persisted
/// (size + privacy); we keep only whether one was attached.
class AnalysisRecord {
  const AnalysisRecord({
    required this.id,
    required this.createdAt,
    required this.messagePreview,
    required this.hadImage,
    required this.analyses,
  });

  factory AnalysisRecord.fromJson(Map<String, dynamic> json) {
    final rawAnalyses = json['analyses'];
    final analyses = <String, ScamAnalysis>{};
    if (rawAnalyses is Map) {
      for (final entry in rawAnalyses.entries) {
        final value = entry.value;
        if (value is Map) {
          analyses[entry.key as String] = ScamAnalysis.fromJson(Map<String, dynamic>.from(value));
        }
      }
    }
    if (analyses.isEmpty) throw const FormatException('record without analyses');
    return AnalysisRecord(
      id: json['id'] as String,
      createdAt: DateTime.parse(json['createdAt'] as String),
      messagePreview: (json['messagePreview'] as String?) ?? '',
      hadImage: (json['hadImage'] as bool?) ?? false,
      analyses: analyses,
    );
  }

  static const previewMaxChars = 400;

  final String id;
  final DateTime createdAt;
  final String messagePreview;
  final bool hadImage;

  /// Verdict per language code ("en", "fr"). At least one entry.
  final Map<String, ScamAnalysis> analyses;

  /// Verdict in [languageCode] if we have it, otherwise any available one.
  ScamAnalysis analysisFor(String languageCode) => analyses[languageCode] ?? analyses.values.first;

  /// The language codes of verdicts we have for this record.
  Iterable<String> get availableLanguages => analyses.keys;

  AnalysisRecord withAnalysis(String languageCode, ScamAnalysis analysis) =>
      AnalysisRecord(
        id: id,
        createdAt: createdAt,
        messagePreview: messagePreview,
        hadImage: hadImage,
        analyses: {...analyses, languageCode: analysis},
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'createdAt': createdAt.toUtc().toIso8601String(),
        'messagePreview': messagePreview,
        'hadImage': hadImage,
        'analyses': analyses.map((k, v) => MapEntry(k, v.toJson())),
      };

  static String makePreview(String message) {
    final collapsed = message.trim().replaceAll(RegExp(r'\s+'), ' ');
    return collapsed.length <= previewMaxChars ? collapsed : '${collapsed.substring(0, previewMaxChars)}…';
  }
}
