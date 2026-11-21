import 'package:flutter/widgets.dart';

/// Spacing, on a 4-point grid. Gaps and padding come from here so the rhythm
/// is the same on every screen.
abstract final class AppSpacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 12;
  static const double lg = 16;
  static const double xl = 24;
  static const double xxl = 32;
  static const double xxxl = 48;
}

/// Corner radii. Kept small on purpose: controls and panels are rectangles
/// with softened corners, not pills.
abstract final class AppRadii {
  static const double tag = 4;
  static const double control = 8;
  static const double panel = 12;

  /// A row in the navigation.
  static const double row = 10;

  static const BorderRadius tagAll = BorderRadius.all(Radius.circular(tag));
  static const BorderRadius controlAll = BorderRadius.all(Radius.circular(control));
  static const BorderRadius panelAll = BorderRadius.all(Radius.circular(panel));
  static const BorderRadius rowAll = BorderRadius.all(Radius.circular(row));
}

/// Fixed sizes shared by more than one widget.
abstract final class AppSizes {
  /// The smallest height of anything that can be tapped.
  static const double minTapTarget = 44;

  /// The height of a text field and of a primary button.
  static const double controlHeight = 48;

  /// The height of a row in the sidebar.
  static const double navRowHeight = 46;

  /// The widest a line of running text is allowed to get.
  static const double readingWidth = 720;

  /// The widest a full page (the Insights grid) gets.
  static const double pageWidth = 1080;

  /// The widest the Home column (the check panel and its results) gets.
  static const double contentWidth = 640;

  static const double sidebarWidth = 248;
  static const double railWidth = 84;
}

/// The three layouts the app has, chosen from the width it is given.
enum AppLayout {
  /// Phones: one column, bottom navigation.
  compact,

  /// Small tablets and narrow windows: a slim navigation rail.
  medium,

  /// Large tablets and desktop windows: a labelled sidebar.
  expanded;

  static AppLayout forWidth(double width) {
    if (width < 600) return AppLayout.compact;
    if (width < 1024) return AppLayout.medium;
    return AppLayout.expanded;
  }
}

/// Motion. Short, and switched off entirely for people who have asked the
/// system to reduce motion.
abstract final class AppMotion {
  static const Duration quick = Duration(milliseconds: 120);
  static const Duration standard = Duration(milliseconds: 200);
  static const Curve curve = Curves.easeOutCubic;

  /// True when the person has turned animations off in system settings.
  static bool reduced(BuildContext context) => MediaQuery.disableAnimationsOf(context);

  /// [duration], or zero when motion is reduced.
  static Duration of(BuildContext context, [Duration duration = standard]) {
    return reduced(context) ? Duration.zero : duration;
  }
}
