import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:the_app/core/pixel_font.dart';

/// A line in the app's pixel letters (Round 34): [parts] side by side,
/// each in its own colour, [pixel] logical pixels a dot (snapped to whole
/// device pixels, like Pip's room).
class PixelText extends StatelessWidget {
  final List<(String, Color)> parts;
  final double pixel;

  /// Said by screen readers (the letters are drawn).
  final String label;

  const PixelText(this.parts,
      {super.key, this.pixel = 2.5, required this.label});

  String get _all => parts.map((p) => p.$1).join();

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final dot = math.max(1.0, (pixel * ratio).floorToDouble()) / ratio;
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: SizedBox(
          width: PixelFont.widthOf(_all) * dot,
          height: PixelFont.height * dot,
          child: CustomPaint(painter: _PixelTextPainter(parts, dot)),
        ),
      ),
    );
  }
}

class _PixelTextPainter extends CustomPainter {
  final List<(String, Color)> parts;
  final double dot;

  _PixelTextPainter(this.parts, this.dot);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    var x = 0;
    for (final (text, colour) in parts) {
      paint.color = colour;
      for (final char in text.split('')) {
        final glyph = PixelFont.glyphOf(char);
        for (var r = 0; r < glyph.length; r++) {
          for (var c = 0; c < glyph[r].length; c++) {
            if (glyph[r][c] != '#') continue;
            canvas.drawRect(
              Rect.fromLTWH((x + c) * dot, r * dot, dot, dot),
              paint,
            );
          }
        }
        x += PixelFont.width + PixelFont.gap;
      }
    }
  }

  @override
  bool shouldRepaint(_PixelTextPainter old) =>
      old.dot != dot || old.parts.toString() != parts.toString();
}
