import 'package:flutter/material.dart';

import '../core/app_colors.dart';
import '../core/app_tokens.dart';

/// Makes [child] behave like a control: it can be tapped, hovered, reached
/// with Tab and activated with Enter or Space, and it shows a clear ring
/// while it has keyboard focus.
///
/// Material's own buttons get the same ring from the theme. This is for the
/// custom rows (navigation items, expandable breach rows) that aren't buttons.
class Tappable extends StatefulWidget {
  const Tappable({
    super.key,
    required this.onTap,
    required this.child,
    this.borderRadius = AppRadii.controlAll,
    this.color = Colors.transparent,
  });

  final VoidCallback? onTap;
  final Widget child;
  final BorderRadius borderRadius;

  /// The resting background. Hover and press tints are layered on top.
  final Color color;

  @override
  State<Tappable> createState() => _TappableState();
}

class _TappableState extends State<Tappable> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    // Only draw the ring for keyboard focus, not after a tap or click.
    final keyboard = FocusManager.instance.highlightMode == FocusHighlightMode.traditional;
    final showRing = _focused && keyboard;

    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        borderRadius: widget.borderRadius,
        border: Border.all(
          color: showRing ? AppColors.accent : Colors.transparent,
          width: 2,
        ),
      ),
      child: Material(
        color: widget.color,
        borderRadius: widget.borderRadius,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onTap,
          onFocusChange: (focused) => setState(() => _focused = focused),
          focusColor: Colors.transparent,
          hoverColor: AppColors.hoverOverlay,
          highlightColor: AppColors.pressedOverlay,
          child: widget.child,
        ),
      ),
    );
  }
}
