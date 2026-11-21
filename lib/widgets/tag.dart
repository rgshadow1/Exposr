import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_tokens.dart';

/// A small rectangular label: a kind of exposed data, or a status.
///
/// With no [tone] it is neutral; with one, its text and edge take that colour.
/// A status tag should also carry an [icon], so it never relies on colour.
class Tag extends StatelessWidget {
  const Tag(this.label, {super.key, this.tone, this.icon});

  final String label;
  final Color? tone;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final tone = this.tone;
    final foreground = tone ?? AppColors.textSecondary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone == null ? AppColors.surfaceRaised : AppColors.tint(tone),
        borderRadius: AppRadii.tagAll,
        border: Border.all(color: tone == null ? AppColors.border : AppColors.tintBorder(tone)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 3),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: 14, color: foreground),
              const SizedBox(width: 6),
            ],
            // Flexible lets a very long label wrap instead of overflowing.
            Flexible(
              child: Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(color: foreground),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
