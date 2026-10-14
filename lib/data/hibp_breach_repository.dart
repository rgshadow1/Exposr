import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../models/breach.dart';
import 'breach_check_exception.dart';
import 'breach_repository.dart';

/// [BreachRepository] backed by the Have I Been Pwned v3 API (or a proxy that
/// exposes the same path).
///
/// This is the only file in the app that knows about HTTP. Its job is to turn
/// every possible outcome of a network request into either a list of
/// [Breach] objects or a [BreachCheckException].
///
/// Privacy note: the email address is part of the request URL. It is never
/// logged here, and errors from the `http` package (whose messages include
/// the URL) are converted into [BreachCheckException]s, which don't.
class HibpBreachRepository implements BreachRepository {
  HibpBreachRepository({required AppConfig config, required http.Client client})
      : _config = config,
        _client = client;

  final AppConfig _config;

  /// Injected rather than created here, so tests can pass a `MockClient` and
  /// the app can close the client when it shuts down.
  final http.Client _client;

  @override
  Future<List<Breach>> findBreaches(String email) async {
    if (!_config.isConfigured) {
      throw const BreachCheckException(BreachCheckFailure.notConfigured);
    }
    if (_config.securityProblem != null) {
      throw const BreachCheckException(BreachCheckFailure.insecureConfiguration);
    }

    final response = await _send(buildRequestUri(email));
    return _handleResponse(response);
  }

  /// Builds `{base}/breachedaccount/{email}?truncateResponse=false`.
  ///
  /// The email is percent-encoded (`@` becomes `%40`) as HIBP asks.
  /// `truncateResponse=false` requests full breach details instead of just
  /// names, which saves one request per breach.
  @visibleForTesting
  Uri buildRequestUri(String email) {
    final base = _config.baseUrl.toString().replaceFirst(RegExp(r'/+$'), '');
    final encodedEmail = Uri.encodeComponent(email.trim());
    return Uri.parse('$base/breachedaccount/$encodedEmail?truncateResponse=false');
  }

  Map<String, String> get _headers => {
        'user-agent': _config.userAgent,
        'accept': 'application/json',
        if (_config.apiKey != null) 'hibp-api-key': _config.apiKey!,
      };

  Future<http.Response> _send(Uri uri) async {
    try {
      return await _client.get(uri, headers: _headers).timeout(_config.requestTimeout);
    } on TimeoutException {
      throw const BreachCheckException(BreachCheckFailure.timeout);
    } on http.ClientException {
      // DNS failure, refused connection, dropped connection, etc.
      throw const BreachCheckException(BreachCheckFailure.noConnection);
    } on Exception {
      // Anything else raised while connecting, e.g. a TLS handshake failure,
      // which the http package passes through unwrapped. Errors (bugs) are
      // not caught here and will still surface during development.
      throw const BreachCheckException(BreachCheckFailure.noConnection);
    }
  }

  List<Breach> _handleResponse(http.Response response) {
    final status = response.statusCode;

    switch (status) {
      case 200:
        return _parseBreaches(response.bodyBytes);
      case 404:
        // HIBP uses 404 to mean "this address isn't in any breach". But a
        // wrong base URL also produces 404s, usually with an HTML error page.
        // Treating that as "no breaches" would give false reassurance, so a
        // 404 with an HTML body is reported as an error instead.
        if (_looksLikeHtmlPage(response)) {
          throw const BreachCheckException(
            BreachCheckFailure.unexpectedResponse,
            statusCode: 404,
          );
        }
        return const [];
      case 400:
        throw BreachCheckException(BreachCheckFailure.invalidEmail, statusCode: status);
      case 401:
        throw BreachCheckException(BreachCheckFailure.unauthorized, statusCode: status);
      case 403:
        throw BreachCheckException(BreachCheckFailure.forbidden, statusCode: status);
      case 429:
        throw BreachCheckException(
          BreachCheckFailure.rateLimited,
          statusCode: status,
          retryAfter: _parseRetryAfter(response.headers['retry-after']),
        );
      case >= 500 && < 600:
        throw BreachCheckException(BreachCheckFailure.serviceUnavailable, statusCode: status);
      default:
        throw BreachCheckException(BreachCheckFailure.unexpectedResponse, statusCode: status);
    }
  }

  List<Breach> _parseBreaches(List<int> bodyBytes) {
    try {
      // Decode as UTF-8 explicitly: `response.body` falls back to Latin-1
      // when the server omits a charset, which would mangle names like "Sōlo".
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is! List<Object?>) {
        throw const FormatException('Expected a JSON array.');
      }

      final breaches = <Breach>[];
      for (final item in decoded) {
        if (item is! Map<String, Object?>) {
          throw const FormatException('Expected a JSON object.');
        }
        breaches.add(Breach.fromJson(item));
      }
      breaches.sort(_newestFirst);
      return breaches;
    } on FormatException {
      // jsonDecode, utf8.decode and Breach.fromJson all report problems as
      // FormatException.
      throw const BreachCheckException(
        BreachCheckFailure.unexpectedResponse,
        statusCode: 200,
      );
    }
  }

  static int _newestFirst(Breach a, Breach b) {
    final aDate = a.breachDate;
    final bDate = b.breachDate;
    if (aDate == null && bDate == null) return a.title.compareTo(b.title);
    if (aDate == null) return 1;
    if (bDate == null) return -1;
    final byDate = bDate.compareTo(aDate);
    return byDate != 0 ? byDate : a.title.compareTo(b.title);
  }

  /// Checks the body rather than the content-type header, because an empty
  /// 404 is still a valid "not found" whatever header comes with it.
  static bool _looksLikeHtmlPage(http.Response response) {
    final body = utf8.decode(response.bodyBytes, allowMalformed: true).trimLeft();
    return body.startsWith('<');
  }

  /// HIBP sends `retry-after` as a whole number of seconds.
  static Duration? _parseRetryAfter(String? header) {
    final seconds = int.tryParse(header?.trim() ?? '');
    if (seconds == null || seconds < 0) return null;
    return Duration(seconds: seconds);
  }
}
