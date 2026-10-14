import 'dart:async';
import 'dart:convert';

import 'package:breach_checker/config/app_config.dart';
import 'package:breach_checker/data/breach_check_exception.dart';
import 'package:breach_checker/data/hibp_breach_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// These tests use `MockClient` from the http package: it answers requests
/// with whatever the test returns, so every status code and malformed body
/// can be exercised without touching the network.
void main() {
  // Uri has no const constructor, so the configs are `final`, not `const`.
  final hibpUri = Uri.parse(AppConfig.hibpBaseUrl);
  final directConfig = AppConfig(
    baseUrl: hibpUri,
    apiKey: '00000000000000000000000000000000',
  );

  HibpBreachRepository repositoryWith(
    MockClientHandler handler, {
    AppConfig? config,
  }) =>
      HibpBreachRepository(config: config ?? directConfig, client: MockClient(handler));

  Matcher failsWith(BreachCheckFailure failure) => throwsA(
        isA<BreachCheckException>().having((e) => e.failure, 'failure', failure),
      );

  group('request', () {
    test('encodes the email and asks for full breach details', () async {
      late http.Request sent;
      final repository = repositoryWith((request) async {
        sent = request;
        return http.Response('', 404);
      });

      await repository.findBreaches(' Name+Tag@Example.com ');

      expect(
        sent.url.toString(),
        'https://haveibeenpwned.com/api/v3/breachedaccount/Name%2BTag%40Example.com?truncateResponse=false',
      );
      expect(sent.method, 'GET');
      expect(sent.headers['hibp-api-key'], '00000000000000000000000000000000');
      expect(sent.headers['user-agent'], AppConfig.defaultUserAgent);
    });

    test('proxy mode sends no API key and tolerates a trailing slash', () async {
      late http.Request sent;
      final repository = repositoryWith(
        (request) async {
          sent = request;
          return http.Response('', 404);
        },
        config: AppConfig(baseUrl: Uri.parse('https://proxy.example.com/api/v3/'), apiKey: null),
      );

      await repository.findBreaches('name@example.com');

      expect(sent.url.host, 'proxy.example.com');
      expect(sent.url.path, '/api/v3/breachedaccount/name%40example.com');
      expect(sent.headers.containsKey('hibp-api-key'), isFalse);
    });

    test('refuses to run without configuration, and sends nothing', () async {
      var requests = 0;
      final repository = repositoryWith(
        (_) async {
          requests++;
          return http.Response('', 404);
        },
        config: AppConfig(baseUrl: hibpUri, apiKey: null),
      );

      await expectLater(
        repository.findBreaches('name@example.com'),
        failsWith(BreachCheckFailure.notConfigured),
      );
      expect(requests, 0);
    });

    test('refuses an invalid or non-HTTP(S) base URL', () async {
      for (final url in ['ftp://example.com/api', 'not a url']) {
        final repository = repositoryWith(
          (_) async => http.Response('', 404),
          config: AppConfig(baseUrl: Uri.tryParse(url) ?? Uri(), apiKey: null),
        );
        await expectLater(
          repository.findBreaches('name@example.com'),
          failsWith(BreachCheckFailure.insecureConfiguration),
          reason: url,
        );
      }
    });
  });

  group('successful responses', () {
    test('200 returns parsed breaches, newest first', () async {
      final body = jsonEncode([
        {'Name': 'Old', 'Title': 'Old Site', 'BreachDate': '2012-01-01'},
        {'Name': 'Undated', 'Title': 'Undated Site'},
        {'Name': 'New', 'Title': 'New Site', 'BreachDate': '2021-06-15'},
      ]);
      final repository = repositoryWith((_) async => http.Response(body, 200));

      final breaches = await repository.findBreaches('name@example.com');

      expect(breaches.map((b) => b.name), ['New', 'Old', 'Undated']);
    });

    test('decodes UTF-8 even when no charset is given', () async {
      final bytes = utf8.encode(jsonEncode([{'Name': 'Solo', 'Title': 'Sōlo Café'}]));
      final repository = repositoryWith((_) async => http.Response.bytes(bytes, 200));

      final breaches = await repository.findBreaches('name@example.com');

      expect(breaches.single.title, 'Sōlo Café');
    });

    test('404 means the address is not in any breach', () async {
      final repository = repositoryWith((_) async => http.Response('', 404));
      expect(await repository.findBreaches('name@example.com'), isEmpty);
    });

    test('an empty 404 is "not found" whatever its content type', () async {
      final repository = repositoryWith(
        (_) async => http.Response('', 404, headers: {'content-type': 'text/html'}),
      );
      expect(await repository.findBreaches('name@example.com'), isEmpty);
    });

    test('an HTML 404 page (wrong URL) is an error, not a clean result', () async {
      final repository = repositoryWith(
        (_) async => http.Response(
          '<html>Not Found</html>',
          404,
          headers: {'content-type': 'text/html; charset=utf-8'},
        ),
      );
      await expectLater(
        repository.findBreaches('name@example.com'),
        failsWith(BreachCheckFailure.unexpectedResponse),
      );
    });
  });

  group('error status codes', () {
    final cases = {
      400: BreachCheckFailure.invalidEmail,
      401: BreachCheckFailure.unauthorized,
      403: BreachCheckFailure.forbidden,
      429: BreachCheckFailure.rateLimited,
      500: BreachCheckFailure.serviceUnavailable,
      503: BreachCheckFailure.serviceUnavailable,
      302: BreachCheckFailure.unexpectedResponse,
      418: BreachCheckFailure.unexpectedResponse,
    };

    cases.forEach((status, failure) {
      test('$status -> ${failure.name}', () async {
        final repository = repositoryWith((_) async => http.Response('', status));
        await expectLater(repository.findBreaches('name@example.com'), failsWith(failure));
      });
    });

    test('429 carries the retry-after delay', () async {
      final repository = repositoryWith(
        (_) async => http.Response('', 429, headers: {'retry-after': '2'}),
      );

      await expectLater(
        repository.findBreaches('name@example.com'),
        throwsA(
          isA<BreachCheckException>()
              .having((e) => e.retryAfter, 'retryAfter', const Duration(seconds: 2)),
        ),
      );
    });
  });

  group('malformed responses', () {
    final bodies = {
      'invalid JSON': '{not json',
      'an object instead of a list': '{"Name": "Adobe"}',
      'a list of strings': '["Adobe"]',
      'an entry without a Name': '[{"Title": "Adobe"}]',
      'an empty body': '',
    };

    bodies.forEach((description, body) {
      test('200 with $description -> unexpectedResponse', () async {
        final repository = repositoryWith((_) async => http.Response(body, 200));
        await expectLater(
          repository.findBreaches('name@example.com'),
          failsWith(BreachCheckFailure.unexpectedResponse),
        );
      });
    });
  });

  group('network failures', () {
    test('connection errors -> noConnection', () async {
      final repository = repositoryWith(
        (request) async => throw http.ClientException('Connection refused', request.url),
      );
      await expectLater(
        repository.findBreaches('name@example.com'),
        failsWith(BreachCheckFailure.noConnection),
      );
    });

    test('a request that never finishes -> timeout', () async {
      final repository = repositoryWith(
        (_) => Completer<http.Response>().future,
        config: AppConfig(
          baseUrl: hibpUri,
          apiKey: '00000000000000000000000000000000',
          requestTimeout: Duration(milliseconds: 50),
        ),
      );
      await expectLater(
        repository.findBreaches('name@example.com'),
        failsWith(BreachCheckFailure.timeout),
      );
    });

    test('the error never contains the email address', () async {
      final repository = repositoryWith(
        (request) async => throw http.ClientException('Failed', request.url),
      );
      try {
        await repository.findBreaches('secret@example.com');
        fail('Expected an exception');
      } on BreachCheckException catch (error) {
        expect(error.toString(), isNot(contains('secret')));
      }
    });
  });
}
