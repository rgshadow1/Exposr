import 'package:flutter/material.dart';

/// Colours for a status message: a tinted background, readable text/icon
/// colour, and a slightly stronger border.
@immutable
class StatusTone {
  const StatusTone({
    required this.background,
    required this.foreground,
    required this.border,
  });

  final Color background;
  final Color foreground;
  final Color border;

  static StatusTone lerp(StatusTone a, StatusTone b, double t) => StatusTone(
        background: Color.lerp(a.background, b.background, t)!,
        foreground: Color.lerp(a.foreground, b.foreground, t)!,
        border: Color.lerp(a.border, b.border, t)!,
      );
}

/// App-specific status colours, attached to the theme as a [ThemeExtension].
///
/// Material's [ColorScheme] has an `error` colour but nothing for "success" or
/// "warning". A ThemeExtension adds our own named colours to [ThemeData], with
/// separate light and dark values, and widgets read them with
/// `Theme.of(context).extension<StatusColors>()!`.
///
/// Foreground/background pairs were chosen to meet WCAG AA contrast (4.5:1)
/// for body text in both themes.
@immutable
class StatusColors extends ThemeExtension<StatusColors> {
  const StatusColors({
    required this.danger,
    required this.success,
    required this.warning,
  });

  final StatusTone danger;
  final StatusTone success;
  final StatusTone warning;

  static const light = StatusColors(
    danger: StatusTone(
      background: Color(0xFFFDEEEE),
      foreground: Color(0xFF9B1C1C),
      border: Color(0xFFF0C4C4),
    ),
    success: StatusTone(
      background: Color(0xFFEAF6EF),
      foreground: Color(0xFF1B5E3B),
      border: Color(0xFFBFE0CB),
    ),
    warning: StatusTone(
      background: Color(0xFFFFF6E5),
      foreground: Color(0xFF7A4A00),
      border: Color(0xFFEFD6A4),
    ),
  );

  static const dark = StatusColors(
    danger: StatusTone(
      background: Color(0xFF331818),
      foreground: Color(0xFFFFB4AB),
      border: Color(0xFF5C2A2A),
    ),
    success: StatusTone(
      background: Color(0xFF142B1E),
      foreground: Color(0xFF9CD9B4),
      border: Color(0xFF2A4D39),
    ),
    warning: StatusTone(
      background: Color(0xFF31260F),
      foreground: Color(0xFFF2CB80),
      border: Color(0xFF574522),
    ),
  );

  @override
  StatusColors copyWith({
    StatusTone? danger,
    StatusTone? success,
    StatusTone? warning,
  }) =>
      StatusColors(
        danger: danger ?? this.danger,
        success: success ?? this.success,
        warning: warning ?? this.warning,
      );

  /// Used by Flutter to animate smoothly when switching light/dark themes.
  @override
  StatusColors lerp(StatusColors? other, double t) {
    if (other == null) return this;
    return StatusColors(
      danger: StatusTone.lerp(danger, other.danger, t),
      success: StatusTone.lerp(success, other.success, t),
      warning: StatusTone.lerp(warning, other.warning, t),
    );
  }
}

/// Shorthand so widgets can write `context.statusColors.danger`.
extension StatusColorsContext on BuildContext {
  StatusColors get statusColors => Theme.of(this).extension<StatusColors>()!;
}
