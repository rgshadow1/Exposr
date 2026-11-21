import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Faint concentric rings behind the check panel, like the face of a radar.
///
/// Purely a still backdrop: it never moves, it is drawn in a few percent white
/// so it barely registers against the page, and it is hidden from screen
/// readers. It exists to give a wide screen some of the app's identity
/// around the panel instead of an empty canvas.
class RadarBackdrop extends StatelessWidget {
  const RadarBackdrop({super.key, required this.centerY, this.height = 980});

  /// Where the middle of the rings sits, measured down from the top of this
  /// widget.
  final double centerY;

  final double height;

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: IgnorePointer(
        child: RepaintBoundary(
          child: SizedBox(
            height: height,
            width: double.infinity,
            child: CustomPaint(painter: _RingsPainter(centerY)),
          ),
        ),
      ),
    );
  }
}

class _RingsPainter extends CustomPainter {
  const _RingsPainter(this.centerY);

  final double centerY;

  /// Each ring a little fainter than the one inside it.
  static const List<(double, double)> _rings = [
    (150, 0.060),
    (270, 0.045),
    (400, 0.032),
    (540, 0.022),
    (690, 0.014),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, centerY);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;

    for (final (radius, alpha) in _rings) {
      paint.color = Colors.white.withValues(alpha: alpha);
      canvas.drawCircle(center, radius, paint);
    }

    // A single tick on the innermost ring: the radar's "north".
    paint.color = Colors.white.withValues(alpha: 0.09);
    canvas.drawLine(
      center + Offset(0, -_rings.first.$1),
      center + Offset(0, -_rings.first.$1 - 10),
      paint,
    );
    const angle = math.pi / 4;
    for (final turn in [angle, 3 * angle, 5 * angle, 7 * angle]) {
      canvas.drawLine(
        center + Offset(math.cos(turn), math.sin(turn)) * (_rings[1].$1),
        center + Offset(math.cos(turn), math.sin(turn)) * (_rings[1].$1 + 6),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) => oldDelegate.centerY != centerY;
}
