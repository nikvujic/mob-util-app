import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/widgets/pip_sprites.dart';

/// Pip standing still, one [frame] of him (Round 35: Pip Home's card),
/// [pixel] logical pixels a dot, snapped to whole device pixels.
class PipPortrait extends StatelessWidget {
  final PipFrame frame;
  final double pixel;

  const PipPortrait({super.key, this.frame = PipFrame.idle, this.pixel = 4});

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    final dot = math.max(1.0, (pixel * ratio).floorToDouble()) / ratio;
    return ExcludeSemantics(
      child: SizedBox(
        width: PipBrain.width * dot,
        height: PipBrain.height * dot,
        child: CustomPaint(painter: _PortraitPainter(frame, dot)),
      ),
    );
  }
}

class _PortraitPainter extends CustomPainter {
  final PipFrame frame;
  final double dot;

  _PortraitPainter(this.frame, this.dot);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    final rows = PipSprites.frames[frame]!;
    for (var y = 0; y < rows.length; y++) {
      for (var x = 0; x < rows[y].length; x++) {
        final colour = PipSprites.colours[rows[y][x]];
        if (colour == null) continue;
        canvas.drawRect(
          Rect.fromLTWH(x * dot, y * dot, dot, dot),
          paint..color = colour,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PortraitPainter old) =>
      old.frame != frame || old.dot != dot;
}
