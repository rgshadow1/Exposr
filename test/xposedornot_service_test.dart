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

      await service.checkEmail('name@example.com');

      expect(seen.method, 'GET');
      expect(
        seen.url.toString(),
        'https://api.xposedornot.com/v1/check-email/name%40example.com'
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

    test('200 with the not-found body is clean (what the live service sends)', () async {
      final service = serviceFor(
        (_) async => jsonResponse({'Error': 'Not found', 'email': null}),
      );

      expect(await service.checkEmail('name@example.com'), isA<EmailClean>());
    });

    test('200 with an empty list is also clean', () async {
      final service = serviceFor((_) async => jsonResponse({'breaches': <Object>[]}));

      expect(await service.checkEmail('name@example.com'), isA<EmailClean>());
    });

    test('200 with an empty nested list is clean too', () async {
      final service = serviceFor(
        (_) async => jsonResponse({
          'breaches': [<Object>[]],
        }),
      );

      expect(await service.checkEmail('name@example.com'), isA<EmailClean>());
    });

    group('an answer it cannot read is a failure, never a clean result', () {
      final unreadable = <String, http.Response>{
        'a 404 that is not the documented not-found reply': http.Response('<h1>Not Found</h1>', 404),
        'a 404 with some other JSON': http.Response(jsonEncode({'detail': 'no route'}), 404),
        'a 404 that lists breaches': http.Response(
          jsonEncode({
            'breaches': ['Adobe'],
          }),
          404,
        ),
        'an empty object': http.Response('{}', 200),
        'an object with no breaches key': http.Response(jsonEncode({'status': 'success'}), 200),
        'breaches set to null': http.Response(jsonEncode({'breaches': null}), 200),
        'breaches that is not a list': http.Response(jsonEncode({'breaches': 'none'}), 200),
        'a list holding something other than names': http.Response(
          jsonEncode({
            'breaches': [
              {'name': 'Adobe'},
            ],
          }),
          200,
        ),
        'a JSON array instead of an object': http.Response('[]', 200),
        'an empty body': http.Response('', 200),
      };

      for (final MapEntry(key: description, value: response) in unreadable.entries) {
        test(description, () async {
          final service = serviceFor((_) async => response);

          await expectFailure(
            service.checkEmail('name@example.com'),
            BreachApiFailure.unexpectedResponse,
          );
        });
      }
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

    test('the error it throws never carries the address', () async {
      // The underlying error names the full URL, which contains the address.
      final service = serviceFor(
        (request) async => throw http.ClientException('Failed host lookup', request.url),
      );

      Object? caught;
      try {
        await service.checkEmail('private.person@example.com');
      } catch (error) {
        caught = error;
      }

      expect(caught, isA<BreachApiException>());
      expect(caught.toString(), isNot(contains('private.person')));
      expect(caught.toString(), isNot(contains('example.com')));
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

    test('a reply without the ExposedBreaches field is a failure, not "no details"', () async {
      final service = serviceFor((_) async => jsonResponse({'status': 'maintenance'}));

      await expectFailure(
        service.fetchBreachDetails('name@example.com'),
        BreachApiFailure.unexpectedResponse,
      );
    });

    test('a 404 is a failure, not "no details"', () async {
      final service = serviceFor((_) async => http.Response('<h1>Not Found</h1>', 404));

      await expectFailure(
        service.fetchBreachDetails('name@example.com'),
        BreachApiFailure.unexpectedResponse,
      );
    });

    test('a timeout is reported as a timeout', () async {
      final service = serviceFor(
        (_) => Completer<http.Response>().future,
        timeout: const Duration(milliseconds: 20),
      );

      await expectFailure(
        service.fetchBreachDetails('name@example.com'),
        BreachApiFailure.timeout,
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
