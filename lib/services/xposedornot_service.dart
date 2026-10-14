import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/breach.dart';
import '../models/email_check_result.dart';
import 'breach_api_service.dart';

/// [BreachApiService] backed by the free XposedOrNot API.
///
/// Free-tier limits, per network address (from XposedOrNot's documentation):
/// 2 requests/second, and 25/hour and 100/day for each of check-email and
/// breach-analytics. A 429 therefore means "wait", so this class never retries
/// it automatically: retrying would only burn the remaining budget.
class XposedOrNotService implements BreachApiService {
  XposedOrNotService({
    http.Client? client,
    Uri? baseUrl,
    Duration timeout = const Duration(seconds: 15),
  })  : _client = client ?? http.Client(),
        _ownsClient = client == null,
        _baseUrl = baseUrl ?? defaultBaseUrl,
        _timeout = timeout {
    // Email addresses must never travel over plain HTTP.
    if (_baseUrl.scheme != 'https') {
      throw ArgumentError.value(_baseUrl.toString(), 'baseUrl', 'must use https');
    }
  }

  static final Uri defaultBaseUrl = Uri.parse('https://api.xposedornot.com');

  final http.Client _client;
  final bool _ownsClient;
  final Uri _baseUrl;
  final Duration _timeout;

  static const Map<String, String> _headers = {'accept': 'application/json'};

  @override
  Future<EmailCheckResult> checkEmail(String email) async {
    // The address is a path segment, so it is percent-encoded ("@" -> "%40")
    // exactly like the curl example in the API docs. Built as a string
    // because Uri.https would encode the "%" a second time.
    final url = Uri.parse(
      '$_baseUrl/v1/check-email/${Uri.encodeComponent(email)}?include_details=false',
    );

    final response = await _get(url);

    // 404 is the API's normal way of saying "not in any breach".
    if (response.statusCode == 404) return EmailClean(email);
    _throwForBadStatus(response);

    final body = _decodeObject(response);
    final names = _flattenNames(body['breaches']);

    if (names.isNotEmpty) return EmailBreached(email, names);

    // No names: either a clean address, or an error object we don't know.
    final error = body['Error'] ?? body['error'];
    if (error == null || error.toString().toLowerCase().contains('not found')) {
      return EmailClean(email);
    }
    throw const BreachApiException(BreachApiFailure.unexpectedResponse);
  }

  @override
  Future<List<Breach>> fetchBreachDetails(String email) async {
    final url = Uri.parse(
      '$_baseUrl/v1/breach-analytics?email=${Uri.encodeQueryComponent(email)}',
    );

    final response = await _get(url);
    if (response.statusCode == 404) return const [];
    _throwForBadStatus(response);

    final body = _decodeObject(response);

    // For an address that isn't in any breach the API answers 200 with every
    // field null, so a missing list simply means "no details".
    final exposed = body['ExposedBreaches'];
    final list = exposed is Map<String, dynamic> ? exposed['breaches_details'] : null;
    if (list is! List<dynamic>) return const [];

    final breaches = [
      for (final item in list)
        if (item is Map<String, dynamic>) Breach.fromJson(item),
    ];

    // Newest first; within a year, the biggest first.
    breaches.sort((a, b) {
      final byYear = (b.year ?? 0).compareTo(a.year ?? 0);
      return byYear != 0 ? byYear : (b.records ?? 0).compareTo(a.records ?? 0);
    });
    return breaches;
  }

  @override
  void close() {
    if (_ownsClient) _client.close();
  }

  /// Performs the GET and turns every transport problem into a
  /// [BreachApiException], so nothing else escapes this class.
  Future<http.Response> _get(Uri url) async {
    try {
      return await _client.get(url, headers: _headers).timeout(_timeout);
    } on TimeoutException {
      throw const BreachApiException(BreachApiFailure.timeout);
    } on Exception {
      // SocketException, ClientException, TLS errors: all "couldn't connect".
      throw const BreachApiException(BreachApiFailure.noConnection);
    }
  }

  void _throwForBadStatus(http.Response response) {
    final code = response.statusCode;
    if (code >= 200 && code < 300) return;
    if (code == 429) throw const BreachApiException(BreachApiFailure.rateLimited);
    if (code >= 500) throw const BreachApiException(BreachApiFailure.serverError);
    throw const BreachApiException(BreachApiFailure.unexpectedResponse);
  }

  /// Decodes the body as UTF-8 JSON and requires a JSON object.
  Map<String, dynamic> _decodeObject(http.Response response) {
    try {
      final decoded = jsonDecode(utf8.decode(response.bodyBytes));
      if (decoded is Map<String, dynamic>) return decoded;
    } on FormatException {
      // Falls through to the exception below.
    }
    throw const BreachApiException(BreachApiFailure.unexpectedResponse);
  }

  /// The API has returned `breaches` both as `[["A","B"]]` and as `["A","B"]`.
  /// This flattens either into one list of unique, non-empty names.
  static List<String> _flattenNames(Object? raw) {
    final names = <String>{}; // a Set keeps first-seen order and drops repeats

    void visit(Object? node) {
      if (node is String) {
        final name = node.trim();
        if (name.isNotEmpty) names.add(name);
      } else if (node is List<dynamic>) {
        node.forEach(visit);
      }
    }

    visit(raw);
    return names.toList();
  }
}
