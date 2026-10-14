/// Why a breach check failed.
///
/// Each value maps to a specific message in the UI. Keeping this as an enum
/// (instead of passing raw exception messages around) means the UI never
/// shows technical text, and never shows anything that might contain the
/// email address, such as a request URL inside an HTTP error message.
enum BreachCheckFailure {
  /// No API key or proxy URL was provided at build time.
  notConfigured,

  /// The configuration exists but is unsafe (e.g. plain HTTP in release).
  insecureConfiguration,

  /// The device couldn't reach the server at all.
  noConnection,

  /// The server didn't answer in time.
  timeout,

  /// HTTP 400: the API rejected the address format.
  invalidEmail,

  /// HTTP 401: missing or invalid API key.
  unauthorized,

  /// HTTP 403: missing user agent or no access to this endpoint.
  forbidden,

  /// HTTP 429: too many requests.
  rateLimited,

  /// HTTP 5xx: the service is down or blocking us.
  serviceUnavailable,

  /// Any other status code, or a body we couldn't make sense of.
  unexpectedResponse,
}

class BreachCheckException implements Exception {
  const BreachCheckException(this.failure, {this.retryAfter, this.statusCode});

  final BreachCheckFailure failure;

  /// For [BreachCheckFailure.rateLimited]: how long HIBP asked us to wait.
  final Duration? retryAfter;

  /// The HTTP status code, if the failure came from a response.
  final int? statusCode;

  /// Deliberately contains no request details, so it is safe to log.
  @override
  String toString() =>
      'BreachCheckException(${failure.name}${statusCode == null ? '' : ', HTTP $statusCode'})';
}
