import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sabicheck/models/scam_analysis.dart';
import 'package:sabicheck/services/sabicheck_api.dart';

const _okBody = {
  'riskLevel': 'High',
  'confidenceScore': 93,
  'category': 'Mobile Money Scam',
  'summary': 's',
  'explanation': 'e',
  'recommendedActions': ['a'],
  'language': 'en',
  'source': 'gemini',
  'analysisId': 'x1',
};

void main() {
  group('HttpSabiCheckApi', () {
    test('POSTs to /v1/analyze with the contract body and headers', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode(_okBody), 200, headers: {'content-type': 'application/json'});
      });
      final api = HttpSabiCheckApi(baseUrl: 'https://api.test/', client: client, appToken: 'tok', appVersion: '9.9', platform: 'android');

      final result = await api.analyze(
        message: 'send pin',
        languageCode: 'fr',
        image: const ImagePayload(mimeType: 'image/png', base64Data: 'AAAA'),
      );

      expect(captured!.url.toString(), 'https://api.test/v1/analyze', reason: 'trailing slash normalised');
      expect(captured!.method, 'POST');
      expect(captured!.headers['Authorization'], 'Bearer tok');
      expect(captured!.headers['X-App-Version'], '9.9');
      expect(captured!.headers['X-Platform'], 'android');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['message'], 'send pin');
      expect(body['language'], 'fr');
      expect(body['image'], {'mimeType': 'image/png', 'data': 'AAAA'});
      expect(result.analysis.riskLevel, RiskLevel.high);
      expect(result.source, AnalysisSource.gemini);
    });

    test('omits image and Authorization when absent', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode(_okBody), 200);
      });
      final api = HttpSabiCheckApi(baseUrl: 'http://10.0.2.2:8080', client: client);
      await api.analyze(message: 'hi', languageCode: 'en');
      expect(captured!.headers.containsKey('Authorization'), isFalse);
      expect((jsonDecode(captured!.body) as Map).containsKey('image'), isFalse);
    });

    test('maps the backend error envelope to ApiException codes', () async {
      final client = MockClient((req) async => http.Response(
            jsonEncode({'error': {'code': 'rate_limited', 'message': 'slow down'}}),
            429,
          ));
      final api = HttpSabiCheckApi(baseUrl: 'https://api.test', client: client);
      await expectLater(
        api.analyze(message: 'x', languageCode: 'en'),
        throwsA(isA<ApiException>()
            .having((e) => e.code, 'code', ApiErrorCode.rateLimited)
            .having((e) => e.statusCode, 'status', 429)
            .having((e) => e.message, 'message', 'slow down')),
      );
    });

    test('maps unknown error bodies by HTTP status', () async {
      final client = MockClient((req) async => http.Response('<html>Bad gateway</html>', 502));
      final api = HttpSabiCheckApi(baseUrl: 'https://api.test', client: client);
      await expectLater(
        api.analyze(message: 'x', languageCode: 'en'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.upstreamError)),
      );
    });

    test('a 2xx that is not a valid analysis is invalidResponse', () async {
      final client = MockClient((req) async => http.Response(jsonEncode({'riskLevel': 'Critical'}), 200));
      final api = HttpSabiCheckApi(baseUrl: 'https://api.test', client: client);
      await expectLater(
        api.analyze(message: 'x', languageCode: 'en'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.invalidResponse)),
      );
    });

    test('connection failures are ApiErrorCode.network', () async {
      final client = MockClient((req) async => throw http.ClientException('Connection refused'));
      final api = HttpSabiCheckApi(baseUrl: 'https://api.test', client: client);
      await expectLater(
        api.analyze(message: 'x', languageCode: 'en'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.network)),
      );
    });

    test('slow servers hit the client timeout', () async {
      final client = MockClient((req) async {
        await Future<void>.delayed(const Duration(milliseconds: 200));
        return http.Response(jsonEncode(_okBody), 200);
      });
      final api = HttpSabiCheckApi(baseUrl: 'https://api.test', client: client, timeout: const Duration(milliseconds: 20));
      await expectLater(
        api.analyze(message: 'x', languageCode: 'en'),
        throwsA(isA<ApiException>().having((e) => e.code, 'code', ApiErrorCode.timeout)),
      );
    });

    test('translate posts the analysis and parses the result', () async {
      http.Request? captured;
      final client = MockClient((req) async {
        captured = req;
        return http.Response(jsonEncode({..._okBody, 'summary': 'Résumé', 'language': 'fr'}), 200);
      });
      final api = HttpSabiCheckApi(baseUrl: 'https://api.test', client: client);
      final original = ScamAnalysis.fromJson(_okBody);
      final translated = await api.translate(analysis: original, languageCode: 'fr');
      expect(captured!.url.path, '/v1/translate');
      final body = jsonDecode(captured!.body) as Map<String, dynamic>;
      expect(body['language'], 'fr');
      expect((body['analysis'] as Map)['riskLevel'], 'High');
      expect(translated.summary, 'Résumé');
    });
  });
}
