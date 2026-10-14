import 'package:flutter/material.dart';

import '../core/app_colors.dart';

/// A rounded square with a blue-tinted fill and an icon: the app's recurring
/// accent. Used in the header, the email card and the feature cards.
class IconBadge extends StatelessWidget {
  const IconBadge({super.key, required this.icon, this.size = 40});

  final IconData icon;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentSoft.withValues(alpha: 0.28)),
      ),
      child: Icon(icon, size: size * 0.55, color: AppColors.accentSoft),
    );
  }
}
