import 'package:flutter/widgets.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/widgets/pip_sprites.dart';

/// Pip, the app's mascot (Round 25), standing still: his room's idle
/// frame (Round 27: the same 20-wide grid as the room and the launcher
/// icon, `tool/make_icon.py`). Each grid pixel is a whole number of the
/// screen's pixels, so the edges stay crisp. In his own colours, whatever
/// the theme.
class Pip extends StatelessWidget {
  /// About how wide he is; snapped down to whole pixels.
  final double size;

  const Pip({super.key, this.size = 32});

  static List<String> get grid => PipSprites.frames[PipFrame.idle]!;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    // Whole device pixels a grid pixel, at least one.
    final dots =
        (size * ratio / PipBrain.width).floorToDouble().clamp(1.0, 99.0);
    final cell = dots / ratio;
    return Semantics(
      label: 'Pip',
      image: true,
      child: SizedBox(
        width: cell * PipBrain.width,
        height: cell * grid.length,
        child: CustomPaint(painter: _PipPainter(cell)),
      ),
    );
  }
}

class _PipPainter extends CustomPainter {
  final double cell;

  _PipPainter(this.cell);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    for (final (y, row) in Pip.grid.indexed) {
      for (var x = 0; x < row.length; x++) {
        final colour = PipSprites.colours[row[x]];
        if (colour == null) continue;
        canvas.drawRect(
          Rect.fromLTWH(x * cell, y * cell, cell, cell),
          paint..color = colour,
        );
      }
    }
  }

  @override
  bool shouldRepaint(_PipPainter old) => old.cell != cell;
}
