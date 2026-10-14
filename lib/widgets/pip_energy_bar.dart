import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:the_app/core/pixel_font.dart';
import 'package:the_app/core/theme.dart';

/// Pip's energy as a battery of three segments (Round 37): 3 green, 2
/// orange, 1 red, 0 empty; then, with [batteries], the batteries held: a
/// small one and how many. In his pixels, [pixel] logical pixels a dot.
class PipEnergyBar extends StatelessWidget {
  final int segments;
  final int? batteries;
  final double pixel;

  const PipEnergyBar({
    super.key,
    required this.segments,
    this.batteries,
    this.pixel = 2.5,
  });

  /// The colour of [segments] full ones.
  static Color colourOf(int segments) => switch (segments) {
        3 => PipColours.energyFull,
        2 => PipColours.energyHalf,
        _ => PipColours.energyLow,
      };

  /// The icon's width in dots: a 13-wide case and its cap; with the held
  /// count, a gap, a 3-wide battery, a gap and the digit.
  int get _width => 14 + (batteries == null ? 0 : 3 + 3 + 1 + PixelFont.width);

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final dot = math.max(1.0, (pixel * ratio).floorToDouble()) / ratio;
    final held = batteries;
    return Semantics(
      label: 'Energy $segments of 3'
          '${held == null ? '' : ', ${held == 1 ? '1 battery' : '$held batteries'}'}',
      child: ExcludeSemantics(
        child: SizedBox(
          width: _width * dot,
          height: 5 * dot,
          child: CustomPaint(painter: _BarPainter(segments, held, dot)),
        ),
      ),
    );
  }
}

class _BarPainter extends CustomPainter {
  final int segments;
  final int? batteries;
  final double dot;

  _BarPainter(this.segments, this.batteries, this.dot);

  @override
  void paint(Canvas canvas, Size size) {
    void px(int x, int y, Color colour, [int w = 1, int h = 1]) =>
        canvas.drawRect(
          Rect.fromLTWH(x * dot, y * dot, w * dot, h * dot),
          Paint()
            ..isAntiAlias = false
            ..color = colour,
        );

    // The case: a 13 x 5 outline and its cap; inside, three segments of
    // 3 with a dark gap between.
    px(0, 0, PipColours.batteryCase, 13, 1);
    px(0, 4, PipColours.batteryCase, 13, 1);
    px(0, 1, PipColours.batteryCase, 1, 3);
    px(12, 1, PipColours.batteryCase, 1, 3);
    px(13, 1, PipColours.batteryCap, 1, 3);
    px(1, 1, PipColours.panel, 11, 3);
    for (var i = 0; i < 3; i++) {
      px(
          1 + 4 * i,
          1,
          i < segments
              ? PipEnergyBar.colourOf(segments)
              : PipColours.energyEmpty,
          3,
          3);
    }

    final held = batteries;
    if (held == null) return;
    // A small battery, then how many.
    const at = 17;
    px(at + 1, 0, PipColours.batteryCap);
    px(at, 1, PipColours.batteryCase, 3, 4);
    px(at + 1, 2, held > 0 ? PipColours.batteryCharge : PipColours.energyEmpty,
        1, 2);
    final glyph = PixelFont.glyphOf('${held.clamp(0, 9)}');
    for (var y = 0; y < glyph.length; y++) {
      for (var x = 0; x < glyph[y].length; x++) {
        if (glyph[y][x] == '#') px(at + 4 + x, y, PipColours.screen);
      }
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.segments != segments || old.batteries != batteries || old.dot != dot;
}
