import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/app_config.dart';
import '../models/analysis_record.dart';
import '../models/scam_analysis.dart';

/// Local, on-device history of checks (newest first). Backed by SharedPreferences
/// as a JSON list — plenty for ≤100 small records; swap for sqlite if it grows.
class HistoryController extends ChangeNotifier {
  HistoryController(this._prefs) {
    _records = _load();
  }

  static const _kHistory = 'history.records.v1';

  final SharedPreferences _prefs;
  late List<AnalysisRecord> _records;

  List<AnalysisRecord> get records => List.unmodifiable(_records);
  bool get isEmpty => _records.isEmpty;

  AnalysisRecord? byId(String id) {
    for (final r in _records) {
      if (r.id == id) return r;
    }
    return null;
  }

  Future<AnalysisRecord> add({
    required String message,
    required bool hadImage,
    required String languageCode,
    required ScamAnalysis analysis,
    String? id,
  }) async {
    final record = AnalysisRecord(
      id: id == null || id.isEmpty ? DateTime.now().microsecondsSinceEpoch.toString() : id,
      createdAt: DateTime.now(),
      messagePreview: AnalysisRecord.makePreview(message),
      hadImage: hadImage,
      analyses: {languageCode: analysis},
    );
    _records.insert(0, record);
    if (_records.length > AppConfig.maxHistoryEntries) {
      _records = _records.sublist(0, AppConfig.maxHistoryEntries);
    }
    notifyListeners();
    await _save();
    return record;
  }

  /// Attach a translated verdict to an existing record.
  Future<void> addTranslation(String id, String languageCode, ScamAnalysis analysis) async {
    final index = _records.indexWhere((r) => r.id == id);
    if (index < 0) return;
    _records[index] = _records[index].withAnalysis(languageCode, analysis);
    notifyListeners();
    await _save();
  }

  Future<void> remove(String id) async {
    final before = _records.length;
    _records.removeWhere((r) => r.id == id);
    if (_records.length != before) {
      notifyListeners();
      await _save();
    }
  }

  Future<void> clear() async {
    if (_records.isEmpty) return;
    _records = [];
    notifyListeners();
    await _save();
  }

  List<AnalysisRecord> _load() {
    final raw = _prefs.getString(_kHistory);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      final out = <AnalysisRecord>[];
      for (final item in decoded) {
        if (item is Map) {
          try {
            out.add(AnalysisRecord.fromJson(Map<String, dynamic>.from(item)));
          } catch (_) {
            // Skip corrupt entries instead of losing the whole history.
          }
        }
      }
      return out;
    } catch (_) {
      return [];
    }
  }

  Future<void> _save() async {
    final encoded = jsonEncode(_records.map((r) => r.toJson()).toList(growable: false));
    await _prefs.setString(_kHistory, encoded);
  }
}
