import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_tokens.dart';

/// A small spinner. For people who have asked the system to reduce motion it
/// is a still icon instead, and the words beside it carry the meaning.
class Spinner extends StatelessWidget {
  const Spinner({super.key, this.size = 16, this.color = AppColors.accent});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    if (AppMotion.reduced(context)) {
      return ExcludeSemantics(child: Icon(Icons.hourglass_top, size: size, color: color));
    }
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: CircularProgressIndicator(strokeWidth: 2, color: color),
      ),
    );
  }
}

/// "Something is in progress": a spinner and one line of text, announced to
/// screen readers when it appears.
class InlineProgress extends StatelessWidget {
  const InlineProgress(this.label, {super.key});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Row(
        children: [
          const Spinner(),
          const SizedBox(width: AppSpacing.md),
          Flexible(
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}
