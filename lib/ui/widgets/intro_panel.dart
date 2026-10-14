import 'package:flutter/material.dart';

import '../../config/app_config.dart';
import '../../theme/status_colors.dart';
import 'status_banner.dart';

/// Shown before the first search: what happens to the address and what the
/// results can and can't tell you. Plain facts, no marketing.
class IntroPanel extends StatelessWidget {
  const IntroPanel({super.key, required this.config});

  /// Used to describe accurately where the address goes and how.
  final AppConfig config;

  @override
  Widget build(BuildContext context) {
    // In proxy mode the address goes to the user's own server first, so the
    // copy has to say so rather than claim it goes straight to HIBP.
    final recipient = config.usesProxy
        ? 'your configured server, which forwards it to Have I Been Pwned'
        : 'Have I Been Pwned';
    final transport = config.baseUrl.scheme == 'https' ? ' over HTTPS' : '';

    final setupProblem = _setupProblem();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (setupProblem != null) ...[
          StatusBanner(
            tone: context.statusColors.warning,
            icon: Icons.settings_outlined,
            title: 'Setup needed',
            message: setupProblem,
          ),
          const SizedBox(height: 20),
        ],
        Text('Before you check', style: Theme.of(context).textTheme.labelLarge),
        const SizedBox(height: 8),
        _Point(
          icon: Icons.lock_outline,
          text: 'The address is sent$transport to $recipient. '
              'This app doesn’t store it or keep a search history.',
        ),
        const _Point(
          icon: Icons.info_outline,
          text: 'Results only cover breaches that HIBP has loaded. '
              'A clean result doesn’t mean the address has never been exposed.',
        ),
        const _Point(
          icon: Icons.person_outline,
          text: 'Only check addresses you own or have permission to check.',
        ),
      ],
    );
  }

  /// A message explaining what's missing, or null when the app is ready.
  /// Shown up front so the developer sees the problem before trying a search.
  String? _setupProblem() {
    if (!config.isConfigured) {
      return 'No API key or server address was set when this app was built. '
          'Run it with --dart-define-from-file (see the README).';
    }
    return config.securityProblem;
  }
}

class _Point extends StatelessWidget {
  const _Point({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
