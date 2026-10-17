import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import 'exposr_lottie.dart';

/// A tinted panel with an icon, a title and a message, used for every
/// outcome: breaches found, nothing found, and errors.
///
/// The colour carries the mood (red, green, amber) but never the meaning on
/// its own: the icon (or animation) and the words say the same thing, so it
/// still works for people who can't tell the colours apart.
class StatusPanel extends StatelessWidget {
  const StatusPanel({
    super.key,
    required this.tone,
    required this.icon,
    required this.title,
    required this.message,
    this.animationAsset,
    this.children = const [],
  });

  final Color tone;
  final IconData icon;
  final String title;
  final String message;

  /// A Lottie file to show in place of the small icon, above the title.
  final String? animationAsset;

  /// Extra content below the message (chips, buttons, a list).
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final animation = animationAsset;

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
              if (animation != null) ...[
                Center(child: ExposrLottie(asset: animation, size: 96)),
                const SizedBox(height: 4),
                Text(title, textAlign: TextAlign.center, style: textTheme.titleMedium),
              ] else
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
                textAlign: animation != null ? TextAlign.center : TextAlign.start,
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
