import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/lottie_assets.dart';
import '../models/breach.dart';
import '../models/exposure_insights.dart';
import '../state/email_check_controller.dart';
import '../utils/count_format.dart';
import '../utils/failure_text.dart';
import '../widgets/exposr_lottie.dart';
import '../widgets/insight_charts.dart';
import '../widgets/screen_header.dart';

/// The Insights tab: charts and headline numbers drawn from the breach details
/// of the address last checked on Home.
///
/// It reads the same [EmailCheckController] as Home, so there is nothing to
/// keep in sync. When the controller changes, this screen redraws. The numbers
/// come from the [ExposureInsights] class, which turns a list of breaches into
/// counts; this screen only draws them.
class InsightsScreen extends StatelessWidget {
  const InsightsScreen({super.key, required this.controller});

  final EmailCheckController controller;

  static const double _maxContentWidth = 560;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final horizontalPadding = constraints.maxWidth >= 600 ? 32.0 : 20.0;

        return SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(horizontalPadding, 16, horizontalPadding, 24),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const ScreenHeader(
                    title: 'Insights',
                    subtitle: 'What was exposed, and when, for the address you last checked.',
                  ),
                  const SizedBox(height: 24),
                  ListenableBuilder(
                    listenable: controller,
                    builder: (context, _) => _body(context),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _body(BuildContext context) {
    final state = controller.state;

    return switch (state) {
      final LookupBreached breached => _breachedBody(breached),
      LookupClean(:final email) => _EmptyInsights(
          title: 'Nothing to chart',
          message: '$email wasn’t found in any known breach, so there is nothing to analyse.',
        ),
      _ => const _EmptyInsights(
          title: 'No insights yet',
          message: 'Check an email address on Home. If it appears in breaches, '
              'come back here to see what was exposed, and when.',
        ),
    };
  }

  Widget _breachedBody(LookupBreached breached) {
    final count = breached.breachNames.length;

    switch (breached.details) {
      case DetailsIdle():
        return _EmptyInsights(
          title: 'Load the details',
          message: '${breached.email} appears in $count ${count == 1 ? 'breach' : 'breaches'}. '
              'Load the details to see charts of what was exposed. '
              'This uses one more request from the free hourly limit.',
          action: FilledButton(onPressed: controller.loadDetails, child: const Text('Load details')),
        );
      case DetailsLoading():
        return const _EmptyInsights(
          title: 'Loading details…',
          message: 'Fetching the breach details from XposedOrNot.',
          animation: LottieAssets.scan,
          loop: true,
        );
      case DetailsFailed(:final failure):
        return _EmptyInsights(
          title: failureTitle(failure),
          message: failureMessage(failure),
          action: OutlinedButton(onPressed: controller.loadDetails, child: const Text('Try again')),
        );
      case DetailsLoaded():
        final breaches = controller.loadedBreaches;
        if (breaches.isEmpty) {
          return const _EmptyInsights(
            title: 'No details available',
            message: 'XposedOrNot has no extra details for these breaches, so there is nothing to chart.',
          );
        }
        return _Dashboard(email: breached.email, insights: ExposureInsights.fromBreaches(breaches));
    }
  }
}

/// Shown when there is nothing to chart yet: an animated shield, a short
/// explanation and, sometimes, one button.
class _EmptyInsights extends StatelessWidget {
  const _EmptyInsights({
    required this.title,
    required this.message,
    this.action,
    this.animation = LottieAssets.shield,
    this.loop = false,
  });

  final String title;
  final String message;
  final Widget? action;
  final String animation;
  final bool loop;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        Center(child: ExposrLottie(asset: animation, size: 140, loop: loop)),
        const SizedBox(height: 8),
        Text(title, textAlign: TextAlign.center, style: textTheme.titleLarge),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
        ),
        if (action != null) ...[const SizedBox(height: 20), action!],
      ],
    );
  }
}

/// The charts, once the breach details are in.
class _Dashboard extends StatelessWidget {
  const _Dashboard({required this.email, required this.insights});

  final String email;
  final ExposureInsights insights;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    final stats = [
      StatCard(
        label: insights.totalBreaches == 1 ? 'Breach' : 'Breaches',
        value: '${insights.totalBreaches}',
      ),
      StatCard(
        label: 'Records exposed',
        value: formatCompact(insights.totalRecords),
        semanticValue: formatCount(insights.totalRecords),
      ),
      StatCard(
        label: 'Most recent',
        value: insights.latestYear?.toString() ?? 'Unknown',
      ),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Based on $email',
          textAlign: TextAlign.center,
          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        // Three across normally; stacked when the user has set a large text size.
        if (textScale > 1.3)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < stats.length; i++) ...[
                if (i > 0) const SizedBox(height: 12),
                stats[i],
              ],
            ],
          )
        else
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const SizedBox(width: 12),
                  Expanded(child: stats[i]),
                ],
              ],
            ),
          ),
        if (insights.breachesPerYear.isNotEmpty) ...[
          const SizedBox(height: 16),
          InsightCard(
            title: 'Breaches by year',
            subtitle: 'When the breaches happened.',
            child: YearTimeline(breachesPerYear: insights.breachesPerYear),
          ),
        ],
        if (insights.dataTypeCounts.isNotEmpty) ...[
          const SizedBox(height: 16),
          InsightCard(
            title: 'What was exposed',
            subtitle: 'How many of the ${insights.totalBreaches} breaches included each kind of data.',
            child: DataTypeBars(
              counts: insights.dataTypeCounts,
              totalBreaches: insights.totalBreaches,
            ),
          ),
        ],
        const SizedBox(height: 16),
        InsightCard(
          title: 'Password protection',
          subtitle: 'How the services stored passwords when they were breached.',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              PasswordRiskSummary(counts: insights.passwordRiskCounts),
              const SizedBox(height: 8),
              Text(
                _passwordAdvice(insights.passwordRiskCounts),
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// One plain-English sentence about what the password numbers mean.
  static String _passwordAdvice(Map<PasswordRisk, int> counts) {
    final weak = (counts[PasswordRisk.plaintext] ?? 0) + (counts[PasswordRisk.easyToCrack] ?? 0);
    if (weak > 0) {
      return '$weak ${weak == 1 ? 'breach' : 'breaches'} kept passwords in a form that is easy to recover. '
          'If you used a password from there anywhere else, change it.';
    }
    return 'None of these breaches are known to have stored passwords in an easily recovered form. '
        'Changing reused passwords is still a good idea.';
  }
}
