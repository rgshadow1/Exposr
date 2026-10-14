// A small proxy that keeps the Have I Been Pwned API key on a server instead
// of inside the mobile app.
//
// It exposes exactly one route, the same shape as HIBP's:
//
//   GET /api/v3/breachedaccount/{email}
//
// adds the API key and user agent, forwards the request to HIBP, and passes
// the status code and body back. Anything else gets a 403, so the proxy can't
// be used as an open relay to the rest of the HIBP API.
//
// Run it:
//   HIBP_API_KEY=your-key dart run bin/server.dart
//
// Environment variables:
//   HIBP_API_KEY           required
//   PORT                   default 8080
//   BIND_ADDRESS           default 127.0.0.1 (use 0.0.0.0 to accept LAN traffic)
//   RATE_LIMIT_PER_MINUTE  per client IP, default 10
//   ALLOWED_ORIGIN         enables CORS for this origin (for Flutter web)
//
// This is a development/small-deployment server. Before exposing it to the
// internet, put it behind HTTPS (a reverse proxy or your host's TLS) and
// consider authenticating the app, since anyone who finds the URL can use
// your HIBP quota.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

const _hibpBase = 'https://haveibeenpwned.com/api/v3/breachedaccount/';
const _userAgent = 'BreachChecker-Proxy/1.0';
const _upstreamTimeout = Duration(seconds: 15);

Future<void> main() async {
  final env = Platform.environment;
  final apiKey = env['HIBP_API_KEY']?.trim() ?? '';
  if (apiKey.isEmpty) {
    stderr.writeln('HIBP_API_KEY is not set. Refusing to start.');
    exitCode = 64;
    return;
  }

  final port = int.tryParse(env['PORT'] ?? '') ?? 8080;
  final bindAddress = env['BIND_ADDRESS'] ?? InternetAddress.loopbackIPv4.address;
  final proxy = _BreachProxy(
    apiKey: apiKey,
    allowedOrigin: env['ALLOWED_ORIGIN'],
    rateLimiter: _RateLimiter(
      maxRequests: int.tryParse(env['RATE_LIMIT_PER_MINUTE'] ?? '') ?? 10,
      window: const Duration(minutes: 1),
    ),
  );

  final server = await HttpServer.bind(bindAddress, port);
  stdout.writeln('Proxy listening on http://${server.address.address}:${server.port}');

  await for (final request in server) {
    // Handle requests concurrently. The catchError is a last line of defence
    // (e.g. the client disconnected mid-response) so one bad request can
    // never crash the server.
    unawaited(
      proxy.handle(request).catchError((Object error) {
        stderr.writeln('Request handling failed: ${error.runtimeType}');
      }),
    );
  }
}

class _BreachProxy {
  _BreachProxy({required this.apiKey, required this.rateLimiter, this.allowedOrigin});

  final String apiKey;
  final String? allowedOrigin;
  final _RateLimiter rateLimiter;
  final HttpClient _client = HttpClient()..connectionTimeout = const Duration(seconds: 10);

  Future<void> handle(HttpRequest request) async {
    final response = request.response;
    final stopwatch = Stopwatch()..start();

    try {
      final origin = allowedOrigin;
      if (origin != null) {
        response.headers
          ..set('access-control-allow-origin', origin)
          ..set('vary', 'origin');
      }

      if (request.method == 'OPTIONS' && origin != null) {
        response.headers
          ..set('access-control-allow-methods', 'GET')
          ..set('access-control-allow-headers', 'accept, user-agent');
        response.statusCode = HttpStatus.noContent;
        return;
      }

      final email = _emailFromPath(request);
      if (request.method != 'GET' || email == null) {
        _sendJson(response, HttpStatus.forbidden, 'Only GET /api/v3/breachedaccount/{email} is supported.');
        return;
      }
      if (email.isEmpty || email.length > 254 || !email.contains('@')) {
        _sendJson(response, HttpStatus.badRequest, 'Invalid email address.');
        return;
      }

      final clientIp = request.connectionInfo?.remoteAddress.address ?? 'unknown';
      final wait = rateLimiter.retryAfter(clientIp);
      if (wait != null) {
        response.headers.set('retry-after', wait.inSeconds.toString());
        _sendJson(response, HttpStatus.tooManyRequests, 'Rate limit exceeded.');
        return;
      }

      await _forward(email, response);
    } on TimeoutException {
      _sendJson(response, HttpStatus.gatewayTimeout, 'Upstream request timed out.');
    } on IOException catch (error) {
      // Log the exception type only; messages can contain the upstream URL,
      // and that URL contains the email address.
      stderr.writeln('Upstream request failed: ${error.runtimeType}');
      _sendJson(response, HttpStatus.badGateway, 'Upstream request failed.');
    } catch (error) {
      stderr.writeln('Unexpected error: ${error.runtimeType}');
      _sendJson(response, HttpStatus.internalServerError, 'Internal error.');
    } finally {
      // Deliberately no email address or path in the log.
      stdout.writeln('${request.method} -> ${response.statusCode} (${stopwatch.elapsedMilliseconds} ms)');
      await response.close();
    }
  }

  /// Returns the decoded email from `/api/v3/breachedaccount/{email}`, or null
  /// if the path doesn't match that route.
  String? _emailFromPath(HttpRequest request) {
    final List<String> segments;
    try {
      segments = request.uri.pathSegments;
    } on Error {
      // Malformed percent-encoding, e.g. "%ZZ". Treat as an invalid email.
      return '';
    }
    final matches = segments.length == 4 &&
        segments[0] == 'api' &&
        segments[1] == 'v3' &&
        segments[2].toLowerCase() == 'breachedaccount';
    return matches ? segments[3].trim() : null;
  }

  Future<void> _forward(String email, HttpResponse response) async {
    // Query parameters from the client are ignored: the proxy always asks
    // for full breach details and nothing else.
    final upstreamUri = Uri.parse('$_hibpBase${Uri.encodeComponent(email)}?truncateResponse=false');

    final upstreamRequest = await _client.getUrl(upstreamUri).timeout(_upstreamTimeout);
    upstreamRequest.headers
      ..set('hibp-api-key', apiKey)
      ..set(HttpHeaders.userAgentHeader, _userAgent)
      ..set(HttpHeaders.acceptHeader, 'application/json');

    final upstream = await upstreamRequest.close().timeout(_upstreamTimeout);
    final body = await upstream
        .fold<BytesBuilder>(BytesBuilder(copy: false), (builder, chunk) => builder..add(chunk))
        .timeout(_upstreamTimeout);

    response.statusCode = upstream.statusCode;
    final contentType = upstream.headers.contentType;
    if (contentType != null) response.headers.contentType = contentType;
    final retryAfter = upstream.headers.value('retry-after');
    if (retryAfter != null) response.headers.set('retry-after', retryAfter);
    response.add(body.takeBytes());
  }

  void _sendJson(HttpResponse response, int status, String message) {
    response.statusCode = status;
    response.headers.contentType = ContentType.json;
    response.write(jsonEncode({'statusCode': status, 'message': message}));
  }
}

/// Fixed-window rate limiter keyed by client IP, kept in memory.
///
/// Protects your HIBP quota from a single client hammering the proxy. It
/// resets when the server restarts, which is fine for this purpose.
class _RateLimiter {
  _RateLimiter({required this.maxRequests, required this.window});

  final int maxRequests;
  final Duration window;
  final Map<String, _Window> _windows = {};

  /// Records a request from [key]. Returns null if it's allowed, or how long
  /// the client should wait if it's over the limit.
  Duration? retryAfter(String key) {
    final now = DateTime.now();
    _windows.removeWhere((_, w) => now.difference(w.start) >= window);

    final current = _windows.putIfAbsent(key, () => _Window(now));
    if (current.count < maxRequests) {
      current.count++;
      return null;
    }
    final remaining = window - now.difference(current.start);
    // Round up so the client never retries a moment too early.
    return Duration(seconds: (remaining.inMilliseconds / 1000).ceil());
  }
}

class _Window {
  _Window(this.start);

  final DateTime start;
  int count = 0;
}
