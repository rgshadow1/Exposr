import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_tokens.dart';
import '../core/lottie_assets.dart';
import '../models/breach.dart';
import '../models/exposure_insights.dart';
import '../state/email_check_controller.dart';
import '../utils/count_format.dart';
import '../utils/failure_text.dart';
import '../widgets/app_page.dart';
import '../widgets/insight_charts.dart';

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

  @override
  Widget build(BuildContext context) {
    return AppPage(
      title: 'Insights',
      subtitle: 'What was exposed, and when, for the address you last checked.',
      maxWidth: 960,
      children: [
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => _body(context),
        ),
      ],
    );
  }

  Widget _body(BuildContext context) {
    final state = controller.state;

    return switch (state) {
      final LookupBreached breached => _breachedBody(breached),
      LookupClean(:final email) => _Notice(
          child: EmptyState(
            icon: Icons.bar_chart,
            title: 'Nothing to chart',
            message: '$email wasn’t found in any breach known to XposedOrNot, so there is '
                'nothing to analyse.',
          ),
        ),
      _ => const _Notice(
          child: EmptyState(
            icon: Icons.insights_outlined,
            title: 'No insights yet',
            message: 'Check an email address on Home. If it appears in breaches, '
                'come back here to see what was exposed, and when.',
          ),
        ),
    };
  }

  Widget _breachedBody(LookupBreached breached) {
    final count = breached.breachNames.length;

    switch (breached.details) {
      case DetailsIdle():
        return _Notice(
          child: EmptyState(
            icon: Icons.insights_outlined,
            title: 'Load the details',
            message: '${breached.email} appears in $count ${count == 1 ? 'breach' : 'breaches'}. '
                'Load the details to see charts of what was exposed. '
                'This uses one more request from XposedOrNot’s free hourly limit.',
            action: FilledButton(
              onPressed: controller.loadDetails,
              child: const Text('Load details'),
            ),
          ),
        );
      case DetailsLoading():
        return const _Notice(
          child: EmptyState(
            icon: Icons.radar,
            animation: LottieAssets.scan,
            loop: true,
            title: 'Loading details…',
            message: 'Fetching the breach details from XposedOrNot.',
          ),
        );
      case DetailsFailed(:final failure):
        return _Notice(
          child: EmptyState(
            icon: Icons.error_outline,
            animation: null,
            tone: AppColors.warning,
            title: failureTitle(failure),
            message: failureMessage(failure),
            action: OutlinedButton(
              onPressed: controller.loadDetails,
              child: const Text('Try again'),
            ),
          ),
        );
      case DetailsLoaded():
        final breaches = controller.loadedBreaches;
        if (breaches.isEmpty) {
          return const _Notice(
            child: EmptyState(
              icon: Icons.bar_chart,
              title: 'No details available',
              message: 'XposedOrNot has no extra details for these breaches, so there is '
                  'nothing to chart.',
            ),
          );
        }
        return _Dashboard(email: breached.email, breaches: breaches);
    }
  }
}

/// Keeps a message at a comfortable reading width on a wide page.
class _Notice extends StatelessWidget {
  const _Notice({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topLeft,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 560),
        child: child,
      ),
    );
  }
}

/// The charts, once the breach details are in.
///
/// A StatefulWidget so the counting is done once per set of breaches, not on
/// every rebuild.
class _Dashboard extends StatefulWidget {
  const _Dashboard({required this.email, required this.breaches});

  final String email;
  final List<Breach> breaches;

  @override
  State<_Dashboard> createState() => _DashboardState();
}

class _DashboardState extends State<_Dashboard> {
  late ExposureInsights _insights = ExposureInsights.fromBreaches(widget.breaches);

  @override
  void didUpdateWidget(_Dashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.breaches, widget.breaches)) {
      _insights = ExposureInsights.fromBreaches(widget.breaches);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final insights = _insights;

    final timeline = insights.breachesPerYear.isEmpty
        ? null
        : InsightCard(
            title: 'Breaches by year',
            subtitle: 'The year each breach happened, as reported by XposedOrNot.',
            child: YearTimeline(breachesPerYear: insights.breachesPerYear),
          );
    final dataTypes = insights.dataTypeCounts.isEmpty
        ? null
        : InsightCard(
            title: 'What was exposed',
            subtitle: 'How many of the ${insights.totalBreaches} breaches included each kind of data.',
            child: DataTypeBars(
              counts: insights.dataTypeCounts,
              totalBreaches: insights.totalBreaches,
            ),
          );
    final passwords = InsightCard(
      title: 'Password protection',
      subtitle: 'How the services stored passwords when they were breached.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          PasswordRiskSummary(counts: insights.passwordRiskCounts),
          const SizedBox(height: AppSpacing.sm),
          Text(
            _passwordAdvice(insights.passwordRiskCounts),
            style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
          ),
        ],
      ),
    );

    const gap = SizedBox(height: AppSpacing.lg);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Based on ${widget.email}',
          style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
        ),
        const SizedBox(height: AppSpacing.md),
        StatRow(
          stats: [
            StatCard(
              label: insights.totalBreaches == 1 ? 'Breach' : 'Breaches',
              value: '${insights.totalBreaches}',
            ),
            StatCard(
              // The size of the breaches themselves, not a count of this
              // person's records.
              label: 'Records in these breaches',
              value: formatCompact(insights.totalRecords),
              semanticValue: formatCount(insights.totalRecords),
            ),
            StatCard(
              label: 'Most recent breach',
              value: insights.latestYear?.toString() ?? 'Unknown',
            ),
          ],
        ),
        gap,
        // Two columns of charts when there is room for them.
        LayoutBuilder(
          builder: (context, constraints) {
            if (constraints.maxWidth < 760) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (timeline != null) ...[timeline, gap],
                  if (dataTypes != null) ...[dataTypes, gap],
                  passwords,
                ],
              );
            }
            return Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (timeline != null) ...[timeline, gap],
                      passwords,
                    ],
                  ),
                ),
                if (dataTypes != null) ...[
                  const SizedBox(width: AppSpacing.lg),
                  Expanded(child: dataTypes),
                ],
              ],
            );
          },
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
