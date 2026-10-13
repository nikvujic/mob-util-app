import 'package:flutter/widgets.dart';
import 'package:the_app/core/theme.dart';

/// Pip, the app's mascot (Round 25): the launcher icon's 8-bit robot,
/// drawn from the same 16 x 16 grid (`tool/make_icon.py`). Each grid pixel
/// is a whole number of the screen's pixels, so the edges stay crisp. In
/// his own colours, whatever the theme. Later he gets a room and moves
/// (the ROADMAP's Pip).
class Pip extends StatelessWidget {
  /// About how wide and tall he is; snapped down to whole pixels.
  final double size;

  const Pip({super.key, this.size = 32});

  /// One letter a pixel: '.' empty, then casing, body, screen, face.
  static const grid = [
    '................',
    '.......W........',
    '.......L........',
    '...LLLLLLLLLL...',
    '..LLLLLLLLLLLL..',
    '..LWWWWWWWWWWL..',
    '..LWKKWWWWKKWL..',
    '..LWKKWWWWKKWL..',
    '..LWWWWWWWWWWL..',
    '..LWWKWWWWKWWL..',
    '..LWWWKKKKWWWL..',
    '..LWWWWWWWWWWL..',
    '..LLLLLLLLLLLL..',
    '...OOOOOOOOOO...',
    '...OO......OO...',
    '................',
  ];

  static const colours = {
    'L': PipColours.casing,
    'O': PipColours.body,
    'W': PipColours.screen,
    'K': PipColours.face,
  };

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    // Whole device pixels a grid pixel, at least one.
    final dots = (size * ratio / grid.length).floorToDouble().clamp(1.0, 99.0);
    final cell = dots / ratio;
    return Semantics(
      label: 'Pip',
      image: true,
      child: SizedBox.square(
        dimension: cell * grid.length,
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
        final colour = Pip.colours[row[x]];
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
