import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_theme.dart';
import '../core/app_tokens.dart';
import '../models/breach.dart';
import 'panel.dart';
import 'password_risk.dart';

/// How long the bars take to grow in. Zero when the person has turned
/// animations off in system settings.
Duration _growDuration(BuildContext context) {
  return AppMotion.of(context, const Duration(milliseconds: 500));
}

/// A titled panel, used to frame each chart.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sub = subtitle;

    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(header: true, child: Text(title, style: textTheme.titleMedium)),
          if (sub != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(sub, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
          const SizedBox(height: AppSpacing.xl),
          child,
        ],
      ),
    );
  }
}

/// One headline number with a label over it.
class StatCard extends StatelessWidget {
  const StatCard({super.key, required this.label, required this.value, this.semanticValue});

  final String label;
  final String value;

  /// What a screen reader says instead of [value] (for example the full number
  /// rather than the shortened "152.4M").
  final String? semanticValue;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: AppSpacing.lg),
      child: Semantics(
        label: '$label: ${semanticValue ?? value}',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            const SizedBox(height: AppSpacing.xs),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                style: textTheme.headlineSmall?.copyWith(fontFeatures: AppTheme.tabularFigures),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The headline numbers in one ruled panel: side by side when there is room,
/// stacked when the screen is narrow or the text is large.
class StatRow extends StatelessWidget {
  const StatRow({super.key, required this.stats});

  final List<StatCard> stats;

  @override
  Widget build(BuildContext context) {
    final textScale = MediaQuery.textScalerOf(context).scale(14) / 14;

    return Panel(
      padding: EdgeInsets.zero,
      child: LayoutBuilder(
        builder: (context, constraints) {
          if (constraints.maxWidth < 420 || textScale > 1.3) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const Divider(),
                  stats[i],
                ],
              ],
            );
          }
          // IntrinsicHeight lets the dividers run the full height of the row.
          return IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < stats.length; i++) ...[
                  if (i > 0) const VerticalDivider(width: 1),
                  Expanded(child: stats[i]),
                ],
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A bar chart of breaches per year. Scrolls sideways when there are many years.
class YearTimeline extends StatelessWidget {
  const YearTimeline({super.key, required this.breachesPerYear});

  final Map<int, int> breachesPerYear;

  @override
  Widget build(BuildContext context) {
    final years = breachesPerYear.keys.toList()..sort();
    final maxCount = breachesPerYear.values.fold<int>(1, (a, b) => a > b ? a : b);
    final duration = _growDuration(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        return SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: ConstrainedBox(
            constraints: BoxConstraints(minWidth: constraints.maxWidth),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                for (final year in years)
                  _YearBar(
                    year: year,
                    count: breachesPerYear[year] ?? 0,
                    fraction: (breachesPerYear[year] ?? 0) / maxCount,
                    duration: duration,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _YearBar extends StatelessWidget {
  const _YearBar({
    required this.year,
    required this.count,
    required this.fraction,
    required this.duration,
  });

  final int year;
  final int count;
  final double fraction;
  final Duration duration;

  static const double _barArea = 96;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final numbers = textTheme.bodySmall?.copyWith(fontFeatures: AppTheme.tabularFigures);

    return ConstrainedBox(
      constraints: const BoxConstraints(minWidth: 52),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6),
        child: Semantics(
          label: '$count ${count == 1 ? 'breach' : 'breaches'} in $year',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('$count', style: numbers),
              const SizedBox(height: AppSpacing.xs),
              SizedBox(
                height: _barArea,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: fraction),
                    duration: duration,
                    curve: AppMotion.curve,
                    builder: (context, value, _) {
                      return Container(
                        width: 20,
                        height: math.max(4, _barArea * value),
                        decoration: const BoxDecoration(
                          color: AppColors.accent,
                          borderRadius: BorderRadius.vertical(top: Radius.circular(3)),
                        ),
                      );
                    },
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text('$year', style: numbers?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// Horizontal bars showing how many breaches exposed each kind of data.
class DataTypeBars extends StatelessWidget {
  const DataTypeBars({super.key, required this.counts, required this.totalBreaches, this.maxRows = 8});

  final Map<String, int> counts;
  final int totalBreaches;
  final int maxRows;

  @override
  Widget build(BuildContext context) {
    final sorted = counts.entries.toList()
      ..sort((a, b) {
        final byCount = b.value.compareTo(a.value);
        return byCount != 0 ? byCount : a.key.compareTo(b.key);
      });
    final shown = sorted.take(maxRows).toList();
    final hidden = sorted.length - shown.length;
    final duration = _growDuration(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 14),
          _MeterRow(
            label: shown[i].key,
            count: shown[i].value,
            fraction: totalBreaches == 0 ? 0 : shown[i].value / totalBreaches,
            // Passwords are the item most worth noticing, so they stand out.
            color: mentionsPasswords(shown[i].key) ? AppColors.danger : AppColors.accent,
            duration: duration,
          ),
        ],
        if (hidden > 0) ...[
          const SizedBox(height: 14),
          Text(
            'And $hidden more ${hidden == 1 ? 'kind' : 'kinds'} of data in fewer breaches.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.textMuted),
          ),
        ],
      ],
    );
  }
}

class _MeterRow extends StatelessWidget {
  const _MeterRow({
    required this.label,
    required this.count,
    required this.fraction,
    required this.color,
    required this.duration,
  });

  final String label;
  final int count;
  final double fraction;
  final Color color;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Semantics(
      label: '$label: in $count ${count == 1 ? 'breach' : 'breaches'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(child: Text(label, style: textTheme.bodyMedium)),
              const SizedBox(width: AppSpacing.md),
              Text(
                '$count',
                style: textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                  fontFeatures: AppTheme.tabularFigures,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: const BorderRadius.all(Radius.circular(3)),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: AppColors.border)),
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: math.min(1.0, math.max(0.0, fraction))),
                      duration: duration,
                      curve: AppMotion.curve,
                      builder: (context, value, _) {
                        // heightFactor matters: without it the fill is
                        // given a loose height and collapses to nothing.
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: value,
                            heightFactor: 1,
                            child: ColoredBox(color: color),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// How the breaches stored passwords: one segmented bar and a legend whose
/// words carry the same information as the colours.
class PasswordRiskSummary extends StatelessWidget {
  const PasswordRiskSummary({super.key, required this.counts});

  final Map<PasswordRisk, int> counts;

  static const List<PasswordRisk> _order = [
    PasswordRisk.plaintext,
    PasswordRisk.easyToCrack,
    PasswordRisk.hardToCrack,
    PasswordRisk.unknown,
  ];

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final present = [
      for (final risk in _order)
        if ((counts[risk] ?? 0) > 0) risk,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ClipRRect(
          borderRadius: const BorderRadius.all(Radius.circular(3)),
          child: SizedBox(
            height: 8,
            child: Row(
              // Stretch, so each segment is as tall as the bar. (Left to the
              // default, a segment with no child has no height at all.)
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < present.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: counts[present[i]] ?? 1,
                    child: ColoredBox(color: passwordRiskColor(present[i])),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: AppSpacing.lg),
        for (final risk in present)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: Semantics(
              label: '${passwordRiskLabel(risk)}: ${counts[risk]} '
                  '${counts[risk] == 1 ? 'breach' : 'breaches'}',
              excludeSemantics: true,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color: passwordRiskColor(risk),
                      borderRadius: const BorderRadius.all(Radius.circular(2)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(passwordRiskLabel(risk), style: textTheme.bodyMedium)),
                  Text(
                    '${counts[risk]}',
                    style: textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                      fontFeatures: AppTheme.tabularFigures,
                    ),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
