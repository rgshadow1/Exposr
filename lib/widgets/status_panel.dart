import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';

/// A tinted panel with an icon, a title and a message, used for every
/// outcome: breaches found, nothing found, and errors.
///
/// The colour carries the mood (red, green, amber) but never the meaning on
/// its own: the icon and the words say the same thing, so it still works for
/// people who can't tell the colours apart.
class StatusPanel extends StatelessWidget {
  const StatusPanel({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    required this.message,
    this.children = const [],
  });

  final Color tone;
  final IconData icon;
  final String title;
  final String message;

  /// Extra content below the message (chips, buttons, a list).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // liveRegion: screen readers announce the panel when it appears.
    return Semantics(
      liveRegion: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: tone.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(AppTheme.cardRadius),
          border: Border.all(color: tone.withValues(alpha: 0.4)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, color: tone, size: 24),
                  const SizedBox(width: 12),
                  Expanded(child: Text(title, style: textTheme.titleMedium)),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                message,
                style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
              ),
              for (final child in children) ...[const SizedBox(height: 16), child],
            ],
          ),
        ),
      ),
    );
  }
}
