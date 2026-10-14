import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../models/breach.dart';
import '../utils/count_format.dart';
import 'pill.dart';

/// One breach in the details list: name, when and how big, what was exposed.
class BreachTile extends StatelessWidget {
  const BreachTile({super.key, required this.breach});

  final Breach breach;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    // Only the facts we actually have, joined with a middle dot.
    final facts = [
      if (breach.year != null) '${breach.year}',
      if (breach.records != null) '${formatCount(breach.records!)} records',
      if (breach.industry != null) breach.industry!,
    ].join(' · ');

    final risk = _riskPill(breach.passwordRisk);

    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.inputFill,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(breach.name, style: textTheme.titleSmall),
            if (facts.isNotEmpty) ...[
              const SizedBox(height: 4),
              Text(
                facts,
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
            if (breach.exposedData.isNotEmpty || risk != null) ...[
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (risk != null) risk,
                  for (final kind in breach.exposedData) Pill(kind),
                ],
              ),
            ],
            if (breach.description != null) ...[
              const SizedBox(height: 12),
              Text(
                breach.description!,
                maxLines: 4,
                overflow: TextOverflow.ellipsis,
                style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// A coloured tag for how the passwords were protected, or null when the
  /// breach didn't involve passwords or the API didn't say.
  Pill? _riskPill(PasswordRisk risk) {
    switch (risk) {
      case PasswordRisk.plaintext:
        return const Pill('Passwords in plain text', tone: AppColors.error);
      case PasswordRisk.easyToCrack:
        return const Pill('Passwords easy to crack', tone: AppColors.warning);
      case PasswordRisk.hardToCrack:
        return const Pill('Passwords hard to crack', tone: AppColors.success);
      case PasswordRisk.none:
      case PasswordRisk.unknown:
        return null;
    }
  }
}
