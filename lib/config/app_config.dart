import 'package:flutter/foundation.dart';

/// Build-time configuration for the app.
///
/// Values come from `--dart-define` / `--dart-define-from-file` at build time,
/// never from source code, so no secret ever needs to be committed.
///
/// Two ways to run the app:
///
/// * **Direct mode**: `HIBP_API_KEY` is set and requests go straight to
///   haveibeenpwned.com. The key ends up inside the compiled app, where it can
///   be extracted. Only use this for local development.
/// * **Proxy mode**: `HIBP_API_KEY` is empty and `HIBP_BASE_URL` points at a
///   server you control (see `server/`) which adds the key. Nothing secret
///   ships in the app.
class AppConfig {
  const AppConfig({
    required this.baseUrl,
    required this.apiKey,
    this.userAgent = defaultUserAgent,
    this.requestTimeout = const Duration(seconds: 15),
  });

  /// Reads the values passed with `--dart-define`.
  ///
  /// `String.fromEnvironment` is evaluated at compile time, which is why it
  /// must be called with `const` and a literal name.
  factory AppConfig.fromEnvironment() {
    const rawBaseUrl = String.fromEnvironment(
      'HIBP_BASE_URL',
      defaultValue: hibpBaseUrl,
    );
    const rawApiKey = String.fromEnvironment('HIBP_API_KEY');

    final trimmedKey = rawApiKey.trim();
    return AppConfig(
      // An unparseable value becomes an empty Uri, which [securityProblem]
      // then reports instead of the app crashing on startup.
      baseUrl: Uri.tryParse(rawBaseUrl.trim()) ?? Uri(),
      apiKey: trimmedKey.isEmpty ? null : trimmedKey,
    );
  }

  static const String hibpBaseUrl = 'https://haveibeenpwned.com/api/v3';

  /// HIBP rejects requests without a user agent (HTTP 403) and asks that it
  /// identifies the app honestly.
  static const String defaultUserAgent = 'BreachChecker-Flutter/1.0';

  final Uri baseUrl;

  /// Null in proxy mode.
  final String? apiKey;

  final String userAgent;
  final Duration requestTimeout;

  bool get _pointsAtHibp => baseUrl.host.toLowerCase() == 'haveibeenpwned.com';

  /// True when requests go to a server other than HIBP itself.
  bool get usesProxy => !_pointsAtHibp;

  /// Talking to HIBP directly without a key can never succeed, so treat it as
  /// "not configured" instead of sending a request that will be rejected.
  bool get isConfigured => !_pointsAtHibp || apiKey != null;

  /// Returns a reason the configuration is unsafe, or null if it is fine.
  ///
  /// Plain HTTP is only accepted in debug builds, so a local proxy can be
  /// tested on an emulator. A release build must use HTTPS because the email
  /// address travels in the URL.
  String? get securityProblem {
    if (baseUrl.host.isEmpty) {
      return 'HIBP_BASE_URL is not a valid URL.';
    }
    if (baseUrl.scheme == 'https') return null;
    if (baseUrl.scheme == 'http' && kDebugMode) return null;
    return 'HIBP_BASE_URL must use https:// in release builds.';
  }
}
