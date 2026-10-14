import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// A small rounded label. Used for breach names, kinds of exposed data and
/// the password-risk tag.
///
/// With no [tone] it is a neutral grey pill; with one it is tinted that colour.
class Pill extends StatelessWidget {
  const Pill(this.label, {super.key, this.tone});

  final String label;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final color = tone ?? AppColors.textSecondary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: color.withValues(alpha: tone == null ? 0.10 : 0.14),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: tone == null ? 0.25 : 0.45)),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: tone ?? AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
        ),
      ),
    );
  }
}
