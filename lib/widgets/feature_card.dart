import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import 'icon_badge.dart';

/// A small card with an icon, a title and one or two lines of explanation.
///
/// There is no custom card styling here: [Card] picks up the charcoal fill,
/// border and rounded corners from the theme (see `core/app_theme.dart`).
class FeatureCard extends StatelessWidget {
  const FeatureCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
  });

  final IconData icon;
  final String title;
  final String description;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            IconBadge(icon: icon),
            const SizedBox(height: 14),
            Text(title, style: textTheme.titleSmall),
            const SizedBox(height: 6),
            Text(
              description,
              style: textTheme.bodySmall?.copyWith(color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}
