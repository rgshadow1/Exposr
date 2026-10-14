import 'package:flutter/material.dart';

/// Every colour the app uses, defined once.
///
/// Widgets read these (directly, or through the theme) instead of writing hex
/// codes inline, so restyling the app is a one-file change.
///
/// Text colours were picked to stay above 4.5:1 contrast against the page and
/// card backgrounds, the WCAG AA level for body text.
abstract final class AppColors {
  // Surfaces
  static const Color background = Color(0xFF0A0C10); // page: near-black
  static const Color card = Color(0xFF14181F); // charcoal cards and nav bar
  static const Color inputFill = Color(0xFF0F1217); // text field well
  static const Color border = Color(0xFF252B35); // subtle outlines
  static const Color borderStrong = Color(0xFF343C49); // field outlines

  // Blue accent
  static const Color primary = Color(0xFF2563EB); // filled buttons
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color accentSoft = Color(0xFF6AA3FF); // icons, focus, highlights

  // Text
  static const Color textPrimary = Color(0xFFE8ECF2);
  static const Color textSecondary = Color(0xFF9AA4B2);
  static const Color textHint = Color(0xFF7D8797);

  // Status
  static const Color warning = Color(0xFFF5B14C); // amber: caution
  static const Color error = Color(0xFFF87171); // red: breached / failed
  static const Color success = Color(0xFF34D399); // green: nothing found
}
