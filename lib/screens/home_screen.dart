import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../state/email_check_controller.dart';
import '../widgets/app_header.dart';
import '../widgets/check_results.dart';
import '../widgets/email_check_card.dart';
import '../widgets/feature_card.dart';

/// The Home tab: header, welcome text, the email check card, its results and
/// the feature cards.
///
/// A widget is a small description of a piece of UI, and screens are built by
/// nesting widgets. This one is a [StatelessWidget] because it holds no data
/// that changes itself: the changing parts listen to the [controller].
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.controller});

  final EmailCheckController controller;

  /// On tablets the column stops growing so lines stay readable.
  static const double _maxContentWidth = 560;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // LayoutBuilder tells us how much room we have so we can adapt to it.
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 20.0;

        return SingleChildScrollView(
          // Dragging the page dismisses the keyboard, as users expect.
          keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
          padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 24),
          // Layout: Center + ConstrainedBox caps the width; Column stacks the
          // children vertically; SizedBox adds fixed gaps between them.
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const AppHeader(),
                  const SizedBox(height: 32),
                  // textAlign centres each line inside the text's own box.
                  // (Column's crossAxisAlignment.stretch gives that box the
                  // full width, so "centre" means the middle of the screen.)
                  Text.rich(
                    const TextSpan(
                      text: 'Welcome\n',
                      children: [
                        TextSpan(
                          text: 'Is your email exposed?',
                          style: TextStyle(color: AppColors.accentSoft),
                        ),
                      ],
                    ),
                    textAlign: TextAlign.center,
                    style: textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Find out whether an email address has appeared in known data breaches.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodyLarge?.copyWith(color: AppColors.textSecondary),
                  ),
                  const SizedBox(height: 24),
                  EmailCheckCard(controller: controller),
                  CheckResults(controller: controller),
                  const SizedBox(height: 16),
                  const _FeatureCards(),
                  const SizedBox(height: 24),
                  const _Attribution(),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Credits the data source, as is good practice for any third-party data.
class _Attribution extends StatelessWidget {
  const _Attribution();

  @override
  Widget build(BuildContext context) {
    return Text(
      'Breach data provided by XposedOrNot.',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textHint),
    );
  }
}

/// The two small feature cards: side by side normally, stacked when the
/// screen is narrow or the user has set a large text size.
class _FeatureCards extends StatelessWidget {
  const _FeatureCards();

  @override
  Widget build(BuildContext context) {
    const privacy = FeatureCard(
      icon: Icons.lock_outline,
      title: 'Privacy first',
      description: 'No passwords and no sign-in. Only the email you enter is sent.',
    );
    const intelligence = FeatureCard(
      icon: Icons.travel_explore,
      title: 'Breach intelligence',
      description: 'Checked against XposedOrNot’s database of known data breaches.',
    );

    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 340 || textScale > 1.3) {
          return const Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [privacy, SizedBox(height: 12), intelligence],
          );
        }
        // IntrinsicHeight makes both cards as tall as the taller one.
        return const IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Expanded(child: privacy),
              SizedBox(width: 12),
              Expanded(child: intelligence),
            ],
          ),
        );
      },
    );
  }
}
