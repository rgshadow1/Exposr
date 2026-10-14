import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../../theme/status_colors.dart';

/// A bordered message block used for results and errors.
///
/// One widget for every status keeps success, warning and error messages
/// visually consistent: same layout, only the [tone] changes. When [tone] is
/// null the banner uses neutral surface colours.
class StatusBanner extends StatelessWidget {
  const StatusBanner({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.tone,
    this.footnote,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final StatusTone? tone;

  /// Optional smaller print under the message.
  final String? footnote;

  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final background = tone?.background ?? scheme.surfaceContainerLow;
    final foreground = tone?.foreground ?? scheme.onSurface;
    final border = tone?.border ?? scheme.outlineVariant;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppTheme.radius),
        border: Border.all(color: border),
      ),
      // Screen readers announce the banner as one live region, so a result
      // or error is read out when it appears.
      child: Semantics(
        liveRegion: true,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, color: foreground, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(color: foreground),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: theme.textTheme.bodyMedium?.copyWith(color: foreground),
                  ),
                  if (footnote != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      footnote!,
                      style: theme.textTheme.bodySmall?.copyWith(color: foreground),
                    ),
                  ],
                  if (actions.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    Wrap(spacing: 8, runSpacing: 8, children: actions),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
