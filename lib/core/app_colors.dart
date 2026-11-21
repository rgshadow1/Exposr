import 'package:flutter/material.dart';

/// Every colour the app uses, defined once.
///
/// Widgets read these (directly, or through the theme) instead of writing hex
/// codes inline, so restyling the app is a one-file change.
///
/// Contrast, measured against [background], [surface] and [surfaceRaised]:
/// all three text colours and the accent and status colours stay above 4.5:1
/// (WCAG AA for body text), and [borderControl] stays above 3:1 against the
/// fills it sits on (WCAG 1.4.11, the boundary of an input).
abstract final class AppColors {
  // Backgrounds and surfaces: a cool near-black, each step a little lighter.
  static const Color background = Color(0xFF0B0D11); // the page
  static const Color surface = Color(0xFF12151B); // panels, sidebar, nav bar
  static const Color surfaceRaised = Color(0xFF1A1E26); // hover, selected, dialogs
  static const Color inputFill = Color(0xFF0C0E13); // text field well

  // Borders
  static const Color border = Color(0xFF232832); // hairlines and panel edges
  static const Color borderStrong = Color(0xFF343B48); // secondary buttons
  static const Color borderControl = Color(0xFF5B6476); // inputs, checkboxes

  // Text
  static const Color textPrimary = Color(0xFFECEFF4);
  static const Color textSecondary = Color(0xFFA6AFBD);
  static const Color textMuted = Color(0xFF8792A3); // captions and hints

  // Blue accent
  static const Color primary = Color(0xFF2563EB); // filled buttons
  static const Color primaryHover = Color(0xFF3672F0);
  static const Color primaryPressed = Color(0xFF1D54D0);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color accent = Color(0xFF6AA3FF); // links, focus rings, selection

  // Status. Always paired with an icon and words, never used alone.
  static const Color danger = Color(0xFFF47C7C); // found in breaches
  static const Color warning = Color(0xFFE8B45C); // a check that failed
  static const Color success = Color(0xFF56C596); // a completed, healthy state

  // Interaction states, layered over whatever is underneath.
  static const Color hoverOverlay = Color(0x0FFFFFFF); // 6% white
  static const Color pressedOverlay = Color(0x1AFFFFFF); // 10% white

  /// The fill behind the current navigation item: a faint blue.
  static Color get navSelected => Color.alphaBlend(primary.withValues(alpha: 0.16), surface);

  /// The faint fill behind a status message of the given [tone].
  static Color tint(Color tone) => Color.alphaBlend(tone.withValues(alpha: 0.08), surface);

  /// The edge of a status message of the given [tone].
  static Color tintBorder(Color tone) => Color.alphaBlend(tone.withValues(alpha: 0.32), surface);
}
