import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_tokens.dart';

/// A bordered surface: the one container the app uses to group content.
///
/// With a [tone] it becomes a status message, faintly tinted and edged in
/// that colour. The tint only sets the mood: whatever is inside must still say
/// the same thing with an icon and words.
class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(AppSpacing.xl),
    this.tone,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? tone;

  @override
  Widget build(BuildContext context) {
    final tone = this.tone;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: tone == null ? AppColors.surface : AppColors.tint(tone),
        borderRadius: AppRadii.panelAll,
        border: Border.all(color: tone == null ? AppColors.border : AppColors.tintBorder(tone)),
      ),
      child: Padding(padding: padding, child: child),
    );
  }
}

/// The small uppercase label above a group of content.
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}
