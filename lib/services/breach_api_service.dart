import '../models/breach.dart';
import '../models/email_check_result.dart';

/// Why a lookup failed. The UI turns each one into a message and a next step.
enum BreachApiFailure {
  /// No internet, DNS failure, connection dropped.
  noConnection,

  /// The server did not answer in time.
  timeout,

  /// HTTP 429: the free hourly or daily limit has been used up.
  rateLimited,

  /// HTTP 5xx: the service itself is having trouble.
  serverError,

  /// Anything else: a 4xx we didn't expect, or a body we couldn't parse.
  unexpectedResponse,
}

/// The only error the API layer throws, so callers need exactly one `catch`.
class BreachApiException implements Exception {
  const BreachApiException(this.failure);

  final BreachApiFailure failure;

  @override
  String toString() => 'BreachApiException(${failure.name})';
}

/// What the rest of the app needs from a breach database.
///
/// Screens and the controller depend on this interface, not on a concrete
/// class. The real implementation talks to XposedOrNot; tests pass a fake.
abstract interface class BreachApiService {
  /// Cheap lookup: is this address in any known breach, and which ones?
  Future<EmailCheckResult> checkEmail(String email);

  /// Richer lookup: date, size, data types and so on for each breach.
  /// It is a separate request with its own rate limit, so it is only made
  /// when the user asks for details.
  Future<List<Breach>> fetchBreachDetails(String email);

  /// Releases resources (the HTTP client). Safe to call once, when done.
  void close();
}
