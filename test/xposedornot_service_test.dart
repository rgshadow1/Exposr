import 'dart:async';
import 'dart:convert';

import 'package:breach_checker/models/breach.dart';
import 'package:breach_checker/models/email_check_result.dart';
import 'package:breach_checker/services/breach_api_service.dart';
import 'package:breach_checker/services/xposedornot_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Tests the real service against a mock HTTP client: requests are inspected
/// and replies are scripted, so nothing touches the network.
void main() {
  const jsonHeaders = {'content-type': 'application/json; charset=utf-8'};

  http.Response jsonResponse(Object body, [int status = 200]) =>
      http.Response(jsonEncode(body), status, headers: jsonHeaders);

  XposedOrNotService serviceFor(
    Future<http.Response> Function(http.Request request) handler, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    return XposedOrNotService(client: MockClient(handler), timeout: timeout);
  }

  Future<void> expectFailure(Future<Object?> call, BreachApiFailure failure) {
    return expectLater(
      call,
      throwsA(
        isA<BreachApiException>().having((e) => e.failure, 'failure', failure),
      ),
    );
  }

  group('checkEmail', () {
    test('sends the request exactly like the documented curl example', () async {
      late http.Request seen;
      final service = serviceFor((request) async {
        seen = request;
        return jsonResponse({'breaches': <Object>[], 'email': 'x', 'status': 'success'});
      });

      await service.checkEmail('hdamohammed9@gmail.com');

      expect(seen.method, 'GET');
      expect(
        seen.url.toString(),
        'https://api.xposedornot.com/v1/check-email/hdamohammed9%40gmail.com'
        '?include_details=false',
      );
      expect(seen.headers['accept'], 'application/json');
    });

    test('percent-encodes characters like + in the address', () async {
      late Uri seen;
      final service = serviceFor((request) async {
        seen = request.url;
        return jsonResponse({'breaches': <Object>[]});
      });

      await service.checkEmail('name+tag@example.com');

      expect(seen.toString(), contains('/v1/check-email/name%2Btag%40example.com?'));
    });

    test('nested breach list becomes a result with names', () async {
      final service = serviceFor((_) async => jsonResponse({
            'breaches': [
              ['Adobe', 'LinkedIn'],
            ],
            'email': 'name@example.com',
            'status': 'success',
          }));

      final result = await service.checkEmail('name@example.com');

      expect(result, isA<EmailBreached>());
      expect((result as EmailBreached).breachNames, ['Adobe', 'LinkedIn']);
      expect(result.email, 'name@example.com');
    });

    test('flat breach list works too, and repeats are dropped', () async {
      final service = serviceFor((_) async => jsonResponse({
            'breaches': ['Adobe', 'Adobe', ' ', 'Dropbox'],
          }));

      final result = await service.checkEmail('name@example.com');

      expect((result as EmailBreached).breachNames, ['Adobe', 'Dropbox']);
    });

    test('404 means the address is not in any breach', () async {
      final service = serviceFor(
        (_) async => jsonResponse({'Error': 'Not found', 'email': null}, 404),
      );

      expect(await service.checkEmail('name@example.com'), isA<EmailClean>());
    });

    test('200 with an empty list is also clean', () async {
      final service = serviceFor((_) async => jsonResponse({'breaches': <Object>[]}));

      expect(await service.checkEmail('name@example.com'), isA<EmailClean>());
    });

    test('429 is reported as rate limited, with no automatic retry', () async {
      var calls = 0;
      final service = serviceFor((_) async {
        calls++;
        return jsonResponse({'detail': 'slow down'}, 429);
      });

      await expectFailure(service.checkEmail('name@example.com'), BreachApiFailure.rateLimited);
      expect(calls, 1);
    });

    test('5xx is reported as a server error', () async {
      final service = serviceFor((_) async => http.Response('bad gateway', 502));

      await expectFailure(service.checkEmail('name@example.com'), BreachApiFailure.serverError);
    });

    test('an unexpected 4xx is an unexpected response', () async {
      final service = serviceFor((_) async => http.Response('nope', 400));

      await expectFailure(
        service.checkEmail('name@example.com'),
        BreachApiFailure.unexpectedResponse,
      );
    });

    test('a body that is not JSON is an unexpected response', () async {
      final service = serviceFor((_) async => http.Response('<html>oops</html>', 200));

      await expectFailure(
        service.checkEmail('name@example.com'),
        BreachApiFailure.unexpectedResponse,
      );
    });

    test('an error object we do not recognise is an unexpected response', () async {
      final service = serviceFor((_) async => jsonResponse({'Error': 'Blocked by policy'}));

      await expectFailure(
        service.checkEmail('name@example.com'),
        BreachApiFailure.unexpectedResponse,
      );
    });

    test('a connection failure is reported as no connection', () async {
      final service = serviceFor((_) async => throw http.ClientException('offline'));

      await expectFailure(service.checkEmail('name@example.com'), BreachApiFailure.noConnection);
    });

    test('a slow server is reported as a timeout', () async {
      final service = serviceFor(
        (_) => Completer<http.Response>().future, // never answers
        timeout: const Duration(milliseconds: 20),
      );

      await expectFailure(service.checkEmail('name@example.com'), BreachApiFailure.timeout);
    });
  });

  group('fetchBreachDetails', () {
    test('requests breach-analytics with the address as a query parameter', () async {
      late Uri seen;
      final service = serviceFor((request) async {
        seen = request.url;
        return jsonResponse({'ExposedBreaches': null});
      });

      await service.fetchBreachDetails('name+tag@example.com');

      expect(
        seen.toString(),
        'https://api.xposedornot.com/v1/breach-analytics?email=name%2Btag%40example.com',
      );
    });

    test('parses details, newest first', () async {
      final service = serviceFor((_) async => jsonResponse({
            'ExposedBreaches': {
              'breaches_details': [
                {
                  'breach': 'Adobe',
                  'details': '<p>Customer &amp; billing data.</p>',
                  'domain': 'adobe.com',
                  'industry': 'Technology',
                  'password_risk': 'easytocrack',
                  'verified': 'Yes',
                  'xposed_data': 'Email addresses;Passwords',
                  'xposed_date': '2013',
                  'xposed_records': 152445165,
                },
                {
                  'breach': 'Newer',
                  'xposed_date': '2020',
                  'xposed_records': '1,000',
                },
              ],
            },
            'BreachesSummary': {'site': ''},
          }));

      final breaches = await service.fetchBreachDetails('name@example.com');

      expect(breaches.map((b) => b.name), ['Newer', 'Adobe']);

      final adobe = breaches.last;
      expect(adobe.year, 2013);
      expect(adobe.records, 152445165);
      expect(adobe.exposedData, ['Email addresses', 'Passwords']);
      expect(adobe.passwordRisk, PasswordRisk.easyToCrack);
      expect(adobe.verified, isTrue);
      expect(adobe.description, 'Customer & billing data.'); // HTML removed

      expect(breaches.first.records, 1000); // "1,000" parsed from text
    });

    test('an address with no breaches (all fields null) gives an empty list', () async {
      final service = serviceFor((_) async => jsonResponse({
            'ExposedBreaches': null,
            'BreachesSummary': {'site': ''},
            'BreachMetrics': null,
          }));

      expect(await service.fetchBreachDetails('name@example.com'), isEmpty);
    });

    test('429 is reported as rate limited', () async {
      final service = serviceFor((_) async => http.Response('', 429));

      await expectFailure(
        service.fetchBreachDetails('name@example.com'),
        BreachApiFailure.rateLimited,
      );
    });
  });

  test('refuses a base URL that is not https', () {
    expect(
      () => XposedOrNotService(baseUrl: Uri.parse('http://api.xposedornot.com')),
      throwsArgumentError,
    );
  });
}
