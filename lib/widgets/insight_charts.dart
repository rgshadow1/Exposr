import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/breach.dart';

/// How long the bars take to grow in. Zero when the person has turned
/// animations off in system settings.
Duration _growDuration(BuildContext context) {
  return MediaQuery.disableAnimationsOf(context) ? Duration.zero : const Duration(milliseconds: 650);
}

/// A card with a title, used to frame each chart.
class InsightCard extends StatelessWidget {
  const InsightCard({super.key, required this.title, this.subtitle, required this.child});

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final sub = subtitle;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Semantics(header: true, child: Text(title, style: textTheme.titleMedium)),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(sub, style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
            ],
            const SizedBox(height: 16),
            child,
          ],
        ),
      ),
    );
  }
}

/// One headline number with a label under it.
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

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 16),
        child: Semantics(
          label: '$label: ${semanticValue ?? value}',
          excludeSemantics: true,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  value,
                  style: textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.accentSoft,
                  ),
                ),
              ),
              const SizedBox(height: 4),
              Text(
                label,
                textAlign: TextAlign.center,
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
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
              mainAxisAlignment: MainAxisAlignment.center,
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

    return SizedBox(
      width: 52,
      child: Semantics(
        label: '$count ${count == 1 ? 'breach' : 'breaches'} in $year',
        excludeSemantics: true,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('$count', style: textTheme.bodySmall),
            const SizedBox(height: 4),
            SizedBox(
              height: _barArea,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: fraction),
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  builder: (context, value, _) {
                    return Container(
                      width: 22,
                      height: math.max(4, _barArea * value),
                      decoration: BoxDecoration(
                        color: AppColors.accentSoft,
                        borderRadius: BorderRadius.circular(6),
                      ),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(height: 6),
            Text('$year', style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary)),
          ],
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
            color: shown[i].key.toLowerCase().contains('password') ? AppColors.error : AppColors.accentSoft,
            duration: duration,
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
              Expanded(child: Text(label, style: textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
              const SizedBox(width: 12),
              Text('$count', style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary)),
            ],
          ),
          const SizedBox(height: 6),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: Stack(
                children: [
                  const Positioned.fill(child: ColoredBox(color: AppColors.border)),
                  Positioned.fill(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: 0, end: math.min(1.0, math.max(0.0, fraction))),
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      builder: (context, value, _) {
                        return Align(
                          alignment: Alignment.centerLeft,
                          child: FractionallySizedBox(
                            widthFactor: value,
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
    PasswordRisk.none,
    PasswordRisk.unknown,
  ];

  static Color colorFor(PasswordRisk risk) {
    switch (risk) {
      case PasswordRisk.plaintext:
        return AppColors.error;
      case PasswordRisk.easyToCrack:
        return AppColors.warning;
      case PasswordRisk.hardToCrack:
        return AppColors.accentSoft;
      case PasswordRisk.none:
        return AppColors.success;
      case PasswordRisk.unknown:
        return AppColors.textHint;
    }
  }

  static String labelFor(PasswordRisk risk) {
    switch (risk) {
      case PasswordRisk.plaintext:
        return 'Stored as plain text';
      case PasswordRisk.easyToCrack:
        return 'Easy to crack';
      case PasswordRisk.hardToCrack:
        return 'Hard to crack';
      case PasswordRisk.none:
        return 'No passwords exposed';
      case PasswordRisk.unknown:
        return 'Not stated';
    }
  }

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
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 12,
            child: Row(
              children: [
                for (var i = 0; i < present.length; i++) ...[
                  if (i > 0) const SizedBox(width: 2),
                  Expanded(
                    flex: counts[present[i]] ?? 1,
                    child: ColoredBox(color: colorFor(present[i])),
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        for (final risk in present)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Semantics(
              label: '${labelFor(risk)}: ${counts[risk]} ${counts[risk] == 1 ? 'breach' : 'breaches'}',
              excludeSemantics: true,
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(color: colorFor(risk), shape: BoxShape.circle),
                  ),
                  const SizedBox(width: 10),
                  Expanded(child: Text(labelFor(risk), style: textTheme.bodyMedium)),
                  Text(
                    '${counts[risk]}',
                    style: textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
