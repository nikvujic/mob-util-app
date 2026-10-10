import 'dart:ui' show PathMetric;

import 'package:flutter/material.dart';

/// Draws a dotted rounded border around [child] (e.g. an empty, see-through
/// block).
class DashedBorder extends StatelessWidget {
  final Color color;
  final double radius;
  final double strokeWidth;

  /// Length of each dash and of the gap after it.
  final double dash;
  final double gap;

  final Widget child;

  const DashedBorder({
    super.key,
    required this.color,
    required this.child,
    this.radius = 6,
    this.strokeWidth = 1.5,
    this.dash = 4,
    this.gap = 4,
  });

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedPainter(
        color: color,
        radius: radius,
        strokeWidth: strokeWidth,
        dash: dash,
        gap: gap,
      ),
      child: child,
    );
  }
}

class _DashedPainter extends CustomPainter {
  final Color color;
  final double radius, strokeWidth, dash, gap;

  const _DashedPainter({
    required this.color,
    required this.radius,
    required this.strokeWidth,
    required this.dash,
    required this.gap,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final inset = strokeWidth / 2;
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(inset, inset, size.width - inset, size.height - inset),
          Radius.circular(radius),
        ),
      );
    final paint = Paint()
      ..color = color
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke;
    for (final PathMetric metric in outline.computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash + gap) {
        canvas.drawPath(metric.extractPath(d, d + dash), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedPainter old) =>
      old.color != color ||
      old.radius != radius ||
      old.strokeWidth != strokeWidth ||
      old.dash != dash ||
      old.gap != gap;
}
