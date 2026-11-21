import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_tokens.dart';

/// Builds the app's dark [ThemeData] from the design tokens.
///
/// A theme is a bundle of defaults that every Material widget reads from the
/// widget tree. Styling inputs, buttons, switches and dialogs here lets
/// screens use plain `TextFormField` and `FilledButton` and still look alike.
///
/// The type scale is deliberately short: seven sizes (28, 24, 20, 17, 15 and
/// 16 for input text, 13, 12) and three weights (regular, medium, semibold).
abstract final class AppTheme {
  /// Bundled in assets/fonts and registered in pubspec.yaml, so no font is
  /// ever downloaded at runtime.
  static const String fontFamily = 'Inter';

  static final ThemeData dark = _build();

  /// Lines numbers up in columns (years, record counts).
  static const List<FontFeature> tabularFigures = [FontFeature.tabularFigures()];

  static TextStyle _style(
    double size,
    double lineHeight,
    FontWeight weight, {
    double spacing = 0,
    Color color = AppColors.textPrimary,
  }) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      height: lineHeight / size,
      fontWeight: weight,
      letterSpacing: spacing,
      color: color,
      leadingDistribution: TextLeadingDistribution.even,
    );
  }

  static final TextTheme _text = TextTheme(
    // 28: the heading of the check panel, on screens with room for it.
    displayLarge: _style(28, 34, FontWeight.w600, spacing: -0.6),
    displayMedium: _style(28, 34, FontWeight.w600, spacing: -0.6),
    displaySmall: _style(28, 34, FontWeight.w600, spacing: -0.6),
    headlineLarge: _style(28, 34, FontWeight.w600, spacing: -0.6),
    headlineMedium: _style(28, 34, FontWeight.w600, spacing: -0.6),
    // 24: page titles, and the check panel's heading on phones.
    headlineSmall: _style(24, 30, FontWeight.w600, spacing: -0.4),
    // 20: dialog and app-bar titles.
    titleLarge: _style(20, 26, FontWeight.w600, spacing: -0.2),
    // 17: panel and result titles.
    titleMedium: _style(17, 24, FontWeight.w600, spacing: -0.1),
    // 15: row titles, body text and buttons.
    titleSmall: _style(15, 22, FontWeight.w600),
    bodyLarge: _style(16, 24, FontWeight.w400), // inputs and lead paragraphs
    bodyMedium: _style(15, 23, FontWeight.w400),
    labelLarge: _style(15, 20, FontWeight.w600),
    // 13: captions and field labels.
    bodySmall: _style(13, 19, FontWeight.w400),
    labelMedium: _style(13, 18, FontWeight.w500),
    // 12: uppercase section labels.
    labelSmall: _style(12, 16, FontWeight.w600, spacing: 0.6),
  );

  /// A 2px ring drawn on the control's own edge while it has keyboard focus.
  static WidgetStateProperty<BorderSide?> _focusRing(Color color, {BorderSide? rest}) {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.focused)) return BorderSide(color: color, width: 2);
      return rest;
    });
  }

  static WidgetStateProperty<Color?> _overlay() {
    return WidgetStateProperty.resolveWith((states) {
      if (states.contains(WidgetState.pressed)) return AppColors.pressedOverlay;
      if (states.contains(WidgetState.hovered)) return AppColors.hoverOverlay;
      return Colors.transparent;
    });
  }

  static ThemeData _build() {
    // A ColorScheme is the set of named colours Material widgets pick from
    // ("primary", "surface", "outline", ...). We map our palette onto it.
    const scheme = ColorScheme.dark(
      primary: AppColors.accent,
      onPrimary: AppColors.background,
      primaryContainer: AppColors.primary,
      onPrimaryContainer: AppColors.onPrimary,
      secondary: AppColors.accent,
      onSecondary: AppColors.background,
      error: AppColors.danger,
      onError: AppColors.background,
      surface: AppColors.background,
      onSurface: AppColors.textPrimary,
      onSurfaceVariant: AppColors.textSecondary,
      outline: AppColors.borderControl,
      outlineVariant: AppColors.border,
      surfaceContainerLowest: AppColors.inputFill,
      surfaceContainerLow: AppColors.surface,
      surfaceContainer: AppColors.surface,
      surfaceContainerHigh: AppColors.surfaceRaised,
      surfaceContainerHighest: AppColors.surfaceRaised,
    );

    const controlShape = RoundedRectangleBorder(borderRadius: AppRadii.controlAll);
    const buttonPadding = EdgeInsets.symmetric(horizontal: 20, vertical: 10);
    const buttonSize = Size(64, AppSizes.minTapTarget);
    // Primary buttons are as tall as a text field, so the two line up when
    // they share a row.
    const primaryButtonSize = Size(64, AppSizes.controlHeight);

    OutlineInputBorder inputBorder(Color color, {double width = 1}) {
      return OutlineInputBorder(
        borderRadius: AppRadii.controlAll,
        borderSide: BorderSide(color: color, width: width),
      );
    }

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      fontFamily: fontFamily,
      textTheme: _text,
      scaffoldBackgroundColor: AppColors.background,
      // The same sizes everywhere. (Flutter otherwise shrinks controls on
      // desktop, which also shrinks what a finger can hit on a touch screen.)
      visualDensity: VisualDensity.standard,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      // Hover and press are shown as a flat tint rather than a ripple.
      splashFactory: NoSplash.splashFactory,
      hoverColor: AppColors.hoverOverlay,
      highlightColor: AppColors.pressedOverlay,
      focusColor: AppColors.accent.withValues(alpha: 0.14),
      dividerTheme: const DividerThemeData(color: AppColors.border, thickness: 1, space: 1),
      iconTheme: const IconThemeData(color: AppColors.textSecondary, size: 20),
      cardTheme: const CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: AppRadii.panelAll,
          side: BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationThemeData(
        filled: true,
        fillColor: AppColors.inputFill,
        hoverColor: Colors.transparent,
        hintStyle: _text.bodyLarge?.copyWith(color: AppColors.textMuted),
        errorStyle: _text.bodySmall?.copyWith(color: AppColors.danger),
        errorMaxLines: 3,
        // 12 + a 24px line + 12 = AppSizes.controlHeight.
        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        border: inputBorder(AppColors.borderControl),
        enabledBorder: inputBorder(AppColors.borderControl),
        focusedBorder: inputBorder(AppColors.accent, width: 2),
        errorBorder: inputBorder(AppColors.danger),
        focusedErrorBorder: inputBorder(AppColors.danger, width: 2),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: AppColors.accent,
        selectionColor: AppColors.primary.withValues(alpha: 0.45),
        selectionHandleColor: AppColors.accent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith((states) {
            // Still readable while it is disabled and showing "Checking…".
            if (states.contains(WidgetState.disabled)) {
              return Color.alphaBlend(AppColors.primary.withValues(alpha: 0.55), AppColors.surface);
            }
            if (states.contains(WidgetState.pressed)) return AppColors.primaryPressed;
            if (states.contains(WidgetState.hovered)) return AppColors.primaryHover;
            return AppColors.primary;
          }),
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) {
              return AppColors.onPrimary.withValues(alpha: 0.85);
            }
            return AppColors.onPrimary;
          }),
          overlayColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          minimumSize: const WidgetStatePropertyAll(primaryButtonSize),
          padding: const WidgetStatePropertyAll(buttonPadding),
          shape: const WidgetStatePropertyAll(controlShape),
          side: _focusRing(AppColors.textPrimary),
          textStyle: WidgetStatePropertyAll(_text.labelLarge),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return AppColors.textMuted;
            return AppColors.textPrimary;
          }),
          overlayColor: _overlay(),
          minimumSize: const WidgetStatePropertyAll(buttonSize),
          padding: const WidgetStatePropertyAll(buttonPadding),
          shape: const WidgetStatePropertyAll(controlShape),
          side: _focusRing(
            AppColors.accent,
            rest: const BorderSide(color: AppColors.borderStrong),
          ),
          textStyle: WidgetStatePropertyAll(_text.labelLarge),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: ButtonStyle(
          foregroundColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.disabled)) return AppColors.textMuted;
            return AppColors.accent;
          }),
          overlayColor: _overlay(),
          minimumSize: const WidgetStatePropertyAll(buttonSize),
          padding: const WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
          shape: const WidgetStatePropertyAll(controlShape),
          side: _focusRing(AppColors.accent),
          textStyle: WidgetStatePropertyAll(_text.labelLarge),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: ButtonStyle(
          foregroundColor: const WidgetStatePropertyAll(AppColors.textSecondary),
          overlayColor: _overlay(),
          minimumSize: const WidgetStatePropertyAll(Size.square(AppSizes.minTapTarget)),
          shape: const WidgetStatePropertyAll(controlShape),
          side: _focusRing(AppColors.accent),
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.textMuted;
          if (states.contains(WidgetState.selected)) return AppColors.onPrimary;
          return AppColors.textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.disabled)) return AppColors.surfaceRaised;
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.inputFill;
        }),
        trackOutlineColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.focused)) return AppColors.accent;
          if (states.contains(WidgetState.disabled)) return AppColors.borderStrong;
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return AppColors.borderControl;
        }),
        trackOutlineWidth: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.focused) ? 2.0 : 1.0;
        }),
        overlayColor: _overlay(),
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return AppColors.primary;
          return Colors.transparent;
        }),
        checkColor: const WidgetStatePropertyAll(AppColors.onPrimary),
        side: const BorderSide(color: AppColors.borderControl, width: 1.5),
        shape: const RoundedRectangleBorder(borderRadius: AppRadii.tagAll),
        overlayColor: _overlay(),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: AppColors.textSecondary,
        // No `textColor` here: it would override the quieter colour of the
        // subtitle style below.
        titleTextStyle: _text.bodyMedium?.copyWith(fontWeight: FontWeight.w500),
        subtitleTextStyle: _text.bodySmall?.copyWith(color: AppColors.textSecondary),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: AppSpacing.lg, vertical: AppSpacing.xs),
        minVerticalPadding: 10,
      ),
      navigationBarTheme: NavigationBarThemeData(
        height: 64,
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        indicatorColor: AppColors.navSelected,
        indicatorShape: const RoundedRectangleBorder(borderRadius: AppRadii.rowAll),
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        overlayColor: _overlay(),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            size: 20,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          );
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return _text.labelSmall?.copyWith(
            letterSpacing: 0.1,
            fontWeight: FontWeight.w500,
            color: selected ? AppColors.accent : AppColors.textSecondary,
          );
        }),
      ),
      badgeTheme: BadgeThemeData(
        backgroundColor: AppColors.danger,
        textColor: AppColors.background,
        textStyle: _text.labelSmall?.copyWith(letterSpacing: 0),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: AppColors.surfaceRaised,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.panelAll,
          side: BorderSide(color: AppColors.borderStrong),
        ),
        titleTextStyle: _text.titleLarge,
        contentTextStyle: _text.bodyMedium?.copyWith(color: AppColors.textSecondary),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: AppColors.surfaceRaised,
        contentTextStyle: _text.bodyMedium,
        elevation: 0,
        shape: const RoundedRectangleBorder(
          borderRadius: AppRadii.controlAll,
          side: BorderSide(color: AppColors.borderStrong),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: const BoxDecoration(
          color: AppColors.surfaceRaised,
          borderRadius: AppRadii.tagAll,
          border: Border.fromBorderSide(BorderSide(color: AppColors.borderStrong)),
        ),
        textStyle: _text.bodySmall,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.accent,
        linearTrackColor: AppColors.border,
        circularTrackColor: Colors.transparent,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: const WidgetStatePropertyAll(8),
        radius: const Radius.circular(4),
        thumbColor: WidgetStateProperty.resolveWith((states) {
          final active =
              states.contains(WidgetState.hovered) || states.contains(WidgetState.dragged);
          return AppColors.textMuted.withValues(alpha: active ? 0.7 : 0.35);
        }),
      ),
      appBarTheme: AppBarThemeData(
        backgroundColor: AppColors.background,
        foregroundColor: AppColors.textPrimary,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: _text.titleLarge,
      ),
    );
  }
}
