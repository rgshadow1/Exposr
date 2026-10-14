import 'package:flutter/material.dart';

import 'status_colors.dart';

/// Builds the light and dark [ThemeData].
///
/// Styling lives here rather than in individual widgets, so buttons, inputs
/// and cards look the same everywhere and a design change is a one-file edit.
/// Fonts are the platform defaults (Roboto on Android, San Francisco on iOS):
/// they're well hinted, need no download, and loading fonts from a CDN at
/// runtime would tell a third party every time the app opens.
abstract final class AppTheme {
  /// A muted blue-slate. Everything else in the palette is derived from it.
  static const Color _seed = Color(0xFF2F5D7C);

  static const double radius = 8;

  static ThemeData light() => _build(
        ColorScheme.fromSeed(seedColor: _seed),
        StatusColors.light,
      );

  static ThemeData dark() => _build(
        ColorScheme.fromSeed(seedColor: _seed, brightness: Brightness.dark),
        StatusColors.dark,
      );

  static ThemeData _build(ColorScheme scheme, StatusColors statusColors) {
    final base = ThemeData(colorScheme: scheme);
    final text = base.textTheme;

    final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(radius));
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 14);

    return base.copyWith(
      scaffoldBackgroundColor: scheme.surface,
      extensions: [statusColors],
      textTheme: text.copyWith(
        headlineSmall: text.headlineSmall?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.2,
        ),
        titleMedium: text.titleMedium?.copyWith(fontWeight: FontWeight.w600),
        bodyMedium: text.bodyMedium?.copyWith(height: 1.45),
        bodySmall: text.bodySmall?.copyWith(
          height: 1.4,
          color: scheme.onSurfaceVariant,
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        color: scheme.surfaceContainerLow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radius),
          side: BorderSide(color: scheme.outlineVariant),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radius),
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          shape: shape,
          padding: buttonPadding,
          minimumSize: const Size(0, 48),
          textStyle: text.labelLarge?.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          shape: shape,
          padding: buttonPadding,
          minimumSize: const Size(0, 48),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(shape: shape),
      ),
      dividerTheme: DividerThemeData(color: scheme.outlineVariant, space: 1),
      snackBarTheme: const SnackBarThemeData(behavior: SnackBarBehavior.floating),
    );
  }
}
