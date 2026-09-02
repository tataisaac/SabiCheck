import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:flutter/foundation.dart';

import '../config/app_config.dart';
import '../l10n/app_strings.dart';
import '../models/scam_analysis.dart';
import '../services/image_loader.dart';
import '../services/sabicheck_api.dart';
import '../services/share_receiver.dart';
import 'history_controller.dart';

enum AnalysisStatus { idle, analyzing, translating, done, error }

/// Why the last error happened, mapped to copy by the UI.
enum AnalysisErrorKind {
  emptyInput,
  network,
  timeout,
  rateLimited,
  unauthorized,
  badRequest,
  payloadTooLarge,
  upstream,
  server,
  imageRead,
  imageTooLarge,
  unknown,
}

/// Drives the main "check a message" screen: input, screenshot, verdict,
/// language switching (translation with cache), and share-sheet intake.
class AnalysisController extends ChangeNotifier {
  /// Named parameters are `apiFactory`, `history`, `shareReceiver`, `imageLoader`
  /// (Dart private named parameters: `this._x` exposes the parameter as `x`).
  AnalysisController({
    required this._apiFactory,
    required this._history,
    this._shareReceiver = const NoopShareReceiver(),
    this._imageLoader = const ImageLoader(),
  });

  final SabiCheckApi Function() _apiFactory;
  final HistoryController _history;
  final ShareReceiver _shareReceiver;
  final ImageLoader _imageLoader;

  StreamSubscription<SharedContent>? _shareSub;
  int _requestSeq = 0;

  // ---- Input ----------------------------------------------------------------
  String _message = '';
  PickedImage? _image;

  String get message => _message;
  PickedImage? get image => _image;
  bool get hasInput => _message.trim().isNotEmpty || _image != null;

  // ---- Output ---------------------------------------------------------------
  AnalysisStatus _status = AnalysisStatus.idle;
  AnalysisErrorKind? _error;
  AnalysisResult? _result;
  String? _resultRecordId;

  /// Verdicts keyed by language for the *current* result (avoids re-translating).
  final Map<String, ScamAnalysis> _translations = {};

  AnalysisStatus get status => _status;
  AnalysisErrorKind? get error => _error;
  AnalysisResult? get result => _result;
  bool get isBusy => _status == AnalysisStatus.analyzing || _status == AnalysisStatus.translating;

  /// The verdict to display for [languageCode], if available.
  ScamAnalysis? analysisFor(String languageCode) => _translations[languageCode];

  /// Notifies the UI when content arrives from the share sheet (for a snackbar).
  final ValueNotifier<SharedContent?> lastShared = ValueNotifier<SharedContent?>(null);

  // ---- Input mutations ------------------------------------------------------
  void setMessage(String value) {
    if (value == _message) return;
    _message = value.length > AppConfig.maxTextChars ? value.substring(0, AppConfig.maxTextChars) : value;
    if (_status == AnalysisStatus.error && _error == AnalysisErrorKind.emptyInput) {
      _status = AnalysisStatus.idle;
      _error = null;
    }
    notifyListeners();
  }

  Future<bool> setImageFromFile(XFile file, {String? mimeTypeHint}) async {
    try {
      _image = await _imageLoader.load(file, mimeTypeHint: mimeTypeHint);
      if (_status == AnalysisStatus.error) {
        _status = AnalysisStatus.idle;
        _error = null;
      }
      notifyListeners();
      return true;
    } on ImageTooLargeException {
      _fail(AnalysisErrorKind.imageTooLarge);
    } on UnsupportedImageException {
      _fail(AnalysisErrorKind.imageRead);
    } catch (e) {
      debugPrint('image load failed: $e');
      _fail(AnalysisErrorKind.imageRead);
    }
    return false;
  }

  void removeImage() {
    if (_image == null) return;
    _image = null;
    notifyListeners();
  }

  void clearAll() {
    _message = '';
    _image = null;
    _result = null;
    _resultRecordId = null;
    _translations.clear();
    _status = AnalysisStatus.idle;
    _error = null;
    _requestSeq++; // invalidates any in-flight request
    notifyListeners();
  }

  // ---- Analysis -------------------------------------------------------------
  Future<void> analyze(AppLanguage language) async {
    if (isBusy) return;
    if (!hasInput) {
      _fail(AnalysisErrorKind.emptyInput);
      return;
    }
    final seq = ++_requestSeq;
    _status = AnalysisStatus.analyzing;
    _error = null;
    notifyListeners();

    final messageToSend = _message.trim();
    final imageToSend = _image;
    try {
      final result = await _apiFactory().analyze(
        message: messageToSend,
        languageCode: language.code,
        image: imageToSend?.toPayload(),
      );
      if (seq != _requestSeq) return; // user cleared/re-ran meanwhile

      _result = result;
      _translations
        ..clear()
        ..[result.languageCode] = result.analysis;
      _status = AnalysisStatus.done;
      notifyListeners();

      final record = await _history.add(
        message: messageToSend,
        hadImage: imageToSend != null,
        languageCode: result.languageCode,
        analysis: result.analysis,
        id: result.analysisId,
      );
      _resultRecordId = record.id;
    } on ApiException catch (e) {
      if (seq != _requestSeq) return;
      _fail(_mapApiError(e));
    } catch (e, st) {
      if (seq != _requestSeq) return;
      debugPrint('analyze failed: $e\n$st');
      _fail(AnalysisErrorKind.unknown);
    }
  }

  /// Called when the UI language changes while a verdict is showing.
  /// The user's *input* is never rewritten — only the verdict is translated
  /// (see spec §5.3 discussion: never alter the evidence).
  Future<void> ensureTranslation(AppLanguage language) async {
    final base = _result;
    if (base == null || _translations.containsKey(language.code) || isBusy) return;
    final seq = _requestSeq;
    _status = AnalysisStatus.translating;
    notifyListeners();
    try {
      final translated = await _apiFactory().translate(
        analysis: base.analysis,
        languageCode: language.code,
      );
      if (seq != _requestSeq) return;
      _translations[language.code] = translated;
      _status = AnalysisStatus.done;
      notifyListeners();
      final id = _resultRecordId;
      if (id != null) await _history.addTranslation(id, language.code, translated);
    } on ApiException catch (e) {
      if (seq != _requestSeq) return;
      // Keep the existing verdict visible; surface the error non-destructively.
      _status = AnalysisStatus.done;
      _error = _mapApiError(e);
      notifyListeners();
    } catch (e) {
      if (seq != _requestSeq) return;
      debugPrint('translate failed: $e');
      _status = AnalysisStatus.done;
      _error = AnalysisErrorKind.unknown;
      notifyListeners();
    }
  }

  /// Clears a transient (non-blocking) error such as a failed translation.
  void dismissError() {
    if (_error == null) return;
    _error = null;
    if (_status == AnalysisStatus.error) _status = _result != null ? AnalysisStatus.done : AnalysisStatus.idle;
    notifyListeners();
  }

  // ---- Share sheet ----------------------------------------------------------
  /// Start listening for shared content. Safe to call once from the root widget.
  Future<void> startShareListener() async {
    _shareSub ??= _shareReceiver.stream.listen(_onShared);
    final initial = await _shareReceiver.initialContent();
    if (initial != null) {
      await _onShared(initial);
      await _shareReceiver.reset();
    }
  }

  Future<void> _onShared(SharedContent content) async {
    if (content.isEmpty) return;
    // A share replaces whatever was on screen — that is the user's intent.
    _result = null;
    _resultRecordId = null;
    _translations.clear();
    _status = AnalysisStatus.idle;
    _error = null;
    _message = content.text ?? '';
    _image = null;
    notifyListeners();

    final path = content.imagePath;
    if (path != null && path.isNotEmpty) {
      await setImageFromFile(XFile(path), mimeTypeHint: content.imageMimeType);
    }
    lastShared.value = content;
  }

  // ---- Helpers --------------------------------------------------------------
  void _fail(AnalysisErrorKind kind) {
    _status = AnalysisStatus.error;
    _error = kind;
    notifyListeners();
  }

  static AnalysisErrorKind _mapApiError(ApiException e) => switch (e.code) {
        ApiErrorCode.network => AnalysisErrorKind.network,
        ApiErrorCode.timeout || ApiErrorCode.upstreamTimeout => AnalysisErrorKind.timeout,
        ApiErrorCode.rateLimited => AnalysisErrorKind.rateLimited,
        ApiErrorCode.unauthorized => AnalysisErrorKind.unauthorized,
        ApiErrorCode.badRequest => AnalysisErrorKind.badRequest,
        ApiErrorCode.payloadTooLarge => AnalysisErrorKind.payloadTooLarge,
        ApiErrorCode.upstreamError || ApiErrorCode.invalidModelOutput => AnalysisErrorKind.upstream,
        ApiErrorCode.internal || ApiErrorCode.notFound || ApiErrorCode.invalidResponse => AnalysisErrorKind.server,
        ApiErrorCode.unknown => AnalysisErrorKind.unknown,
      };

  @override
  void dispose() {
    _shareSub?.cancel();
    lastShared.dispose();
    super.dispose();
  }
}

/// Copy for each error kind.
String errorMessageFor(AnalysisErrorKind kind, AppStrings s) => switch (kind) {
      AnalysisErrorKind.emptyInput => s.errorEmptyInput,
      AnalysisErrorKind.network => s.errorNetwork,
      AnalysisErrorKind.timeout => s.errorTimeout,
      AnalysisErrorKind.rateLimited => s.errorRateLimited,
      AnalysisErrorKind.unauthorized => s.errorUnauthorized,
      AnalysisErrorKind.badRequest => s.errorBadRequest,
      AnalysisErrorKind.payloadTooLarge => s.errorPayloadTooLarge,
      AnalysisErrorKind.upstream => s.errorUpstream,
      AnalysisErrorKind.server => s.errorServer,
      AnalysisErrorKind.imageRead => s.errorImageRead,
      AnalysisErrorKind.imageTooLarge => s.errorImageTooLarge,
      AnalysisErrorKind.unknown => s.errorUnknown,
    };
