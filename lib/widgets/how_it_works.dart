import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_tokens.dart';
import 'tappable.dart';

/// The explanations, folded away until someone asks for them.
///
/// The panel itself carries no small print. What a check sends and keeps, what
/// it can and can't tell you, the rule about whose addresses to check, and who
/// the breach data comes from, are all here.
class HowItWorks extends StatefulWidget {
  const HowItWorks({super.key});

  static const String attribution = 'Breach data provided by XposedOrNot.';

  @override
  State<HowItWorks> createState() => _HowItWorksState();
}

class _HowItWorksState extends State<HowItWorks> {
  bool _open = false;

  static const List<(IconData, String, String)> _points = [
    (
      Icons.storage_outlined,
      'What is checked',
      'The breaches XposedOrNot has collected and indexed. Its database is large, but no '
          'breach database is complete.',
    ),
    (
      Icons.fact_check_outlined,
      'What you will see',
      'Which breaches include the address and, if you ask for details, the year of each and '
          'the kinds of data that were exposed.',
    ),
    (
      Icons.help_outline,
      'What it can’t tell you',
      'Whether an account is being misused, or anything about a breach that hasn’t been '
          'reported yet.',
    ),
    (
      Icons.lock_outline,
      'Your privacy',
      'The address is sent over HTTPS to XposedOrNot and nowhere else, and Exposr never logs '
          'it. It is kept only if you add it to your Watchlist, in this device’s own storage, '
          'which is not encrypted.',
    ),
    (
      Icons.person_outline,
      'Whose addresses',
      'Only check addresses you own or have permission to check.',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Center(
          child: Semantics(
            button: true,
            expanded: _open,
            child: Tappable(
              onTap: () => setState(() => _open = !_open),
              child: ConstrainedBox(
                constraints: const BoxConstraints(minHeight: AppSizes.minTapTarget),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Flexible, so at a very large text size the label
                      // wraps instead of running off the panel.
                      Flexible(
                        child: Text(
                          'How it works',
                          style: textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w500,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.xs),
                      ExcludeSemantics(
                        child: AnimatedRotation(
                          turns: _open ? 0.5 : 0,
                          duration: AppMotion.of(context, AppMotion.quick),
                          child:
                              const Icon(Icons.expand_more, size: 20, color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        AnimatedSize(
          duration: AppMotion.of(context),
          curve: AppMotion.curve,
          alignment: Alignment.topCenter,
          child: _open
              ? Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (icon, title, detail) in _points)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          child: MergeSemantics(
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Padding(
                                  padding: const EdgeInsets.only(top: 2),
                                  child: ExcludeSemantics(
                                    child: Icon(icon, size: 18, color: AppColors.textMuted),
                                  ),
                                ),
                                const SizedBox(width: AppSpacing.md),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        title,
                                        style: textTheme.bodyMedium?.copyWith(
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        detail,
                                        style: textTheme.bodySmall?.copyWith(
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      // Under the text of the rows above, not under their icons.
                      Padding(
                        padding: const EdgeInsets.only(left: 30, top: 2, bottom: 4),
                        child: Text(
                          HowItWorks.attribution,
                          style: textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
                        ),
                      ),
                    ],
                  ),
                )
              : const SizedBox(width: double.infinity),
        ),
      ],
    );
  }
}
