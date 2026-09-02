import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/scam_analysis.dart';

/// Stable error codes shared with the backend (`error.code`), plus client-side ones.
enum ApiErrorCode {
  badRequest,
  unauthorized,
  payloadTooLarge,
  rateLimited,
  upstreamError,
  upstreamTimeout,
  invalidModelOutput,
  notFound,
  internal,
  // Client-side
  network,
  timeout,
  invalidResponse,
  unknown;

  static ApiErrorCode fromWire(String? code) => switch (code) {
        'bad_request' => ApiErrorCode.badRequest,
        'unauthorized' => ApiErrorCode.unauthorized,
        'payload_too_large' => ApiErrorCode.payloadTooLarge,
        'rate_limited' => ApiErrorCode.rateLimited,
        'upstream_error' => ApiErrorCode.upstreamError,
        'upstream_timeout' => ApiErrorCode.upstreamTimeout,
        'invalid_model_output' => ApiErrorCode.invalidModelOutput,
        'not_found' => ApiErrorCode.notFound,
        'internal' => ApiErrorCode.internal,
        _ => ApiErrorCode.unknown,
      };
}

class ApiException implements Exception {
  const ApiException(this.code, this.message, {this.statusCode});

  final ApiErrorCode code;
  final String message;
  final int? statusCode;

  @override
  String toString() => 'ApiException($code, $statusCode): $message';
}

/// Image payload for analysis: raw bytes already validated/compressed by the caller.
class ImagePayload {
  const ImagePayload({required this.mimeType, required this.base64Data});

  final String mimeType;
  final String base64Data;
}

/// Client contract — the app depends on this so tests can inject a fake.
abstract class SabiCheckApi {
  Future<AnalysisResult> analyze({
    required String message,
    required String languageCode,
    ImagePayload? image,
  });

  Future<ScamAnalysis> translate({
    required ScamAnalysis analysis,
    required String languageCode,
  });
}

/// HTTP implementation talking to the SabiCheck backend proxy (never Gemini directly).
class HttpSabiCheckApi implements SabiCheckApi {
  HttpSabiCheckApi({
    required String baseUrl,
    http.Client? client,
    this.appToken,
    this.timeout = const Duration(seconds: 45),
    this.appVersion = '0.1.0',
    this.platform = 'unknown',
  })  : _client = client ?? http.Client(),
        _baseUrl = _normalizeBaseUrl(baseUrl);

  final http.Client _client;
  final String _baseUrl;
  final String? appToken;
  final Duration timeout;
  final String appVersion;
  final String platform;

  String get baseUrl => _baseUrl;

  static String _normalizeBaseUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json; charset=utf-8',
        'Accept': 'application/json',
        'X-App-Version': appVersion,
        'X-Platform': platform,
        if (appToken != null && appToken!.isNotEmpty) 'Authorization': 'Bearer $appToken',
      };

  @override
  Future<AnalysisResult> analyze({
    required String message,
    required String languageCode,
    ImagePayload? image,
  }) async {
    final body = <String, dynamic>{
      'message': message,
      'language': languageCode,
      if (image != null) 'image': {'mimeType': image.mimeType, 'data': image.base64Data},
    };
    final json = await _post('/v1/analyze', body);
    try {
      return AnalysisResult.fromJson(json);
    } on FormatException catch (e) {
      throw ApiException(ApiErrorCode.invalidResponse, 'Malformed analysis: ${e.message}');
    }
  }

  @override
  Future<ScamAnalysis> translate({
    required ScamAnalysis analysis,
    required String languageCode,
  }) async {
    final json = await _post('/v1/translate', {
      'language': languageCode,
      'analysis': analysis.toJson(),
    });
    try {
      return ScamAnalysis.fromJson(json);
    } on FormatException catch (e) {
      throw ApiException(ApiErrorCode.invalidResponse, 'Malformed translation: ${e.message}');
    }
  }

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    final uri = Uri.parse('$_baseUrl$path');
    http.Response response;
    try {
      response = await _client.post(uri, headers: _headers, body: jsonEncode(body)).timeout(timeout);
    } on TimeoutException {
      throw const ApiException(ApiErrorCode.timeout, 'Request timed out');
    } on http.ClientException catch (e) {
      throw ApiException(ApiErrorCode.network, e.message);
    }

    final text = utf8.decode(response.bodyBytes, allowMalformed: true);
    Object? decoded;
    try {
      decoded = text.isEmpty ? null : jsonDecode(text);
    } on FormatException {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      if (decoded is Map<String, dynamic>) return decoded;
      throw ApiException(ApiErrorCode.invalidResponse, 'Expected a JSON object', statusCode: response.statusCode);
    }

    // Error envelope: {"error": {"code": "...", "message": "..."}}
    if (decoded is Map<String, dynamic> && decoded['error'] is Map) {
      final err = decoded['error'] as Map;
      throw ApiException(
        ApiErrorCode.fromWire(err['code'] as String?),
        (err['message'] as String?) ?? 'Request failed',
        statusCode: response.statusCode,
      );
    }
    throw ApiException(
      _codeFromStatus(response.statusCode),
      'HTTP ${response.statusCode}',
      statusCode: response.statusCode,
    );
  }

  static ApiErrorCode _codeFromStatus(int status) => switch (status) {
        400 => ApiErrorCode.badRequest,
        401 || 403 => ApiErrorCode.unauthorized,
        404 => ApiErrorCode.notFound,
        413 => ApiErrorCode.payloadTooLarge,
        429 => ApiErrorCode.rateLimited,
        502 || 503 => ApiErrorCode.upstreamError,
        504 => ApiErrorCode.upstreamTimeout,
        _ => status >= 500 ? ApiErrorCode.internal : ApiErrorCode.unknown,
      };
}
