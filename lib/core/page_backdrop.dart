import 'package:flutter/material.dart';

import '../state/email_check_controller.dart';
import 'app_colors.dart';

/// The two colours of the page's background gradient (top and bottom).
///
/// The background follows the result of the last check: dark red when the
/// address was found in breaches, dark green when it wasn't, and the normal
/// near-black otherwise. Both tints stay dark so the text on top keeps its
/// contrast. The colour is only a mood: the result panel always says the same
/// thing in words and with an icon.
class PageBackdrop {
  const PageBackdrop(this.top, this.bottom);

  final Color top;
  final Color bottom;

  static const PageBackdrop neutral = PageBackdrop(AppColors.background, AppColors.background);
  static const PageBackdrop breached = PageBackdrop(Color(0xFF40111A), Color(0xFF12080A));
  static const PageBackdrop clean = PageBackdrop(Color(0xFF0D3D2C), Color(0xFF06140F));

  /// Picks the backdrop for what the results area is showing.
  static PageBackdrop forState(LookupState state) {
    return switch (state) {
      LookupBreached() => breached,
      LookupClean() => clean,
      // Idle, loading and failed all mean "no verdict (yet)".
      LookupIdle() || LookupLoading() || LookupFailed() => neutral,
    };
  }

  LinearGradient get gradient => LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [top, bottom],
      );
}
