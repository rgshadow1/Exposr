import 'package:flutter/material.dart';

import '../../data/breach_check_exception.dart';
import '../../theme/status_colors.dart';
import 'status_banner.dart';

/// Result state when the check couldn't be completed.
///
/// Every [BreachCheckFailure] gets its own wording, telling the user what went
/// wrong in plain terms and, where possible, what to do about it.
class CheckErrorView extends StatelessWidget {
  const CheckErrorView({
    super.key,
    required this.error,
    required this.onRetry,
    required this.onNewSearch,
  });

  final BreachCheckException error;
  final VoidCallback onRetry;
  final VoidCallback onNewSearch;

  @override
  Widget build(BuildContext context) {
    final copy = _ErrorCopy.forException(error);
    final status = context.statusColors;

    return StatusBanner(
      // Configuration problems are the developer's to fix; network problems
      // are temporary. Different tones make that difference visible.
      tone: copy.isConfigurationProblem ? status.danger : status.warning,
      icon: copy.isConfigurationProblem ? Icons.settings_outlined : Icons.cloud_off_outlined,
      title: copy.title,
      message: copy.message,
      footnote: error.statusCode == null ? null : 'HTTP ${error.statusCode}',
      actions: [
        if (copy.canRetry) FilledButton(onPressed: onRetry, child: const Text('Try again')),
        OutlinedButton(onPressed: onNewSearch, child: const Text('New search')),
      ],
    );
  }
}

/// The title, message and retry behaviour for each failure.
class _ErrorCopy {
  const _ErrorCopy(
    this.title,
    this.message, {
    this.canRetry = true,
    this.isConfigurationProblem = false,
  });

  final String title;
  final String message;
  final bool canRetry;
  final bool isConfigurationProblem;

  /// A `switch` expression over an enum must cover every value, so adding a
  /// new failure type without writing copy for it won't compile.
  static _ErrorCopy forException(BreachCheckException error) => switch (error.failure) {
        BreachCheckFailure.notConfigured => const _ErrorCopy(
            'App not configured',
            'No API key or server address was provided when this app was built. '
                'See “Configuring the API” in the README.',
            canRetry: false,
            isConfigurationProblem: true,
          ),
        BreachCheckFailure.insecureConfiguration => const _ErrorCopy(
            'Insecure server address',
            'The configured server address must be a valid https:// URL.',
            canRetry: false,
            isConfigurationProblem: true,
          ),
        BreachCheckFailure.noConnection => const _ErrorCopy(
            'Couldn’t connect',
            'Check your internet connection and try again.',
          ),
        BreachCheckFailure.timeout => const _ErrorCopy(
            'Request timed out',
            'The server took too long to respond. Try again in a moment.',
          ),
        BreachCheckFailure.invalidEmail => const _ErrorCopy(
            'Address not accepted',
            'The breach service rejected this address. Check it for typos.',
            canRetry: false,
          ),
        BreachCheckFailure.unauthorized => const _ErrorCopy(
            'API key rejected',
            'The API key is missing or invalid. Check HIBP_API_KEY in your config '
                'file, or the key set on your server.',
            canRetry: false,
            isConfigurationProblem: true,
          ),
        BreachCheckFailure.forbidden => const _ErrorCopy(
            'Request refused',
            'The service refused this request. Your API plan may not include it, '
                'or your server may be blocking it.',
            canRetry: false,
            isConfigurationProblem: true,
          ),
        BreachCheckFailure.rateLimited => _ErrorCopy(
            'Too many requests',
            _rateLimitMessage(error.retryAfter),
          ),
        BreachCheckFailure.serviceUnavailable => const _ErrorCopy(
            'Service unavailable',
            'Have I Been Pwned is temporarily unavailable. Try again later.',
          ),
        BreachCheckFailure.unexpectedResponse => const _ErrorCopy(
            'Unexpected response',
            'The server sent a response the app couldn’t read. If this keeps '
                'happening, check the configured server address.',
          ),
      };

  static String _rateLimitMessage(Duration? retryAfter) {
    if (retryAfter == null || retryAfter.inSeconds <= 0) {
      return 'The request limit was reached. Wait a moment and try again.';
    }
    final seconds = retryAfter.inSeconds;
    return 'The request limit was reached. Try again in $seconds '
        '${seconds == 1 ? 'second' : 'seconds'}.';
  }
}
