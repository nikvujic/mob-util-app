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

/// Words in the pixel letters (Round 66), wrapped onto as many lines as
/// the width needs (a word longer than a line goes on its own).
class PixelParagraph extends StatelessWidget {
  final String text;
  final Color colour;
  final double pixel;

  /// Between lines, in dots.
  static const lineGap = 3;

  const PixelParagraph(this.text,
      {super.key, required this.colour, this.pixel = 2.5});

  /// [text] in lines of at most [columns] letters, broken between words.
  static List<String> linesOf(String text, int columns) {
    final lines = <String>[];
    var line = '';
    for (final word in text.split(' ').where((w) => w.isNotEmpty)) {
      if (line.isEmpty) {
        line = word;
      } else if (line.length + 1 + word.length <= columns) {
        line = '$line $word';
      } else {
        lines.add(line);
        line = word;
      }
    }
    if (line.isNotEmpty) lines.add(line);
    return lines;
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final dot = math.max(1.0, (pixel * ratio).floorToDouble()) / ratio;
    return Semantics(
      label: text,
      child: ExcludeSemantics(
        child: LayoutBuilder(builder: (context, box) {
          final step = (PixelFont.width + PixelFont.gap) * dot;
          final columns = box.maxWidth.isFinite
              ? math.max(
                  1, ((box.maxWidth + PixelFont.gap * dot) / step).floor())
              : text.length;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final (i, line) in linesOf(text, columns).indexed) ...[
                if (i > 0) SizedBox(height: lineGap * dot),
                SizedBox(
                  width: PixelFont.widthOf(line) * dot,
                  height: PixelFont.height * dot,
                  child: CustomPaint(
                      painter: _PixelTextPainter([(line, colour)], dot)),
                ),
              ],
            ],
          );
        }),
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
