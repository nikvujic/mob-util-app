import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/theme.dart';

/// Pip's room (Round 26): a strip of field at the bottom of the menu where
/// Pip stands about and walks, moved by [brain]. Drawn in pixels (each a
/// whole number of the screen's), crisp at any size. With [animate] off
/// (tests, or the phone's "remove animations") he just stands there.
class PipRoom extends StatefulWidget {
  final PipBrain brain;
  final bool animate;

  const PipRoom({super.key, required this.brain, this.animate = true});

  /// About how big one of Pip's pixels is.
  static const pixel = 2.5;

  /// The room's height, in Pip's pixels: Pip (18), a hop (6), the
  /// ground (5) and a little air.
  static const rows = 32;

  /// The ground's depth, in pixels (the top one grass).
  static const ground = 5;

  @override
  State<PipRoom> createState() => _PipRoomState();
}

class _PipRoomState extends State<PipRoom> with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  Duration _last = Duration.zero;

  void _tick(Duration elapsed) {
    final dt = (elapsed - _last).inMicroseconds / 1e6;
    _last = elapsed;
    // A long pause (e.g. the app away) doesn't jump him across the room.
    setState(() => widget.brain.step(dt.clamp(0, 0.1)));
  }

  bool get _moving =>
      widget.animate &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(PipRoom old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    if (_moving && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!_moving && _ticker.isActive) {
      _ticker.stop();
    }
    // Not moving: he's simply there, standing.
    if (!_moving && !widget.brain.spawned) {
      widget.brain.step(PipBrain.landEnd);
    }
  }

  @override
  void dispose() {
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    // Whole device pixels a room pixel.
    final pixel =
        math.max(1.0, (PipRoom.pixel * ratio).floorToDouble()) / ratio;
    return Semantics(
      key: const Key('pipRoom'),
      label: 'Pip, in his room',
      image: true,
      child: LayoutBuilder(
        builder: (context, box) {
          widget.brain.roomWidth = (box.maxWidth / pixel).floor();
          return SizedBox(
            width: box.maxWidth,
            height: PipRoom.rows * pixel,
            child: CustomPaint(
              painter: _RoomPainter(widget.brain, pixel),
            ),
          );
        },
      ),
    );
  }
}

/// Pip's frames on a 20-wide grid: the same head and face as the icon,
/// finer, with legs that can step.
abstract final class PipSprites {
  static const _head = [
    '.........A..........',
    '.........L..........',
    '...LLLLLLLLLLLLLL...',
    '..LLLLLLLLLLLLLLLL..',
    '..LWWWWWWWWWWWWWWL..',
    '..LWWWWWWWWWWWWWWL..',
    '..LWWWWWWWWWWWWWWL..',
    '..LWWWWWWWWWWWWWWL..',
    '..LWWWWWWWWWWWWWWL..',
    '..LWWWWWWWWWWWWWWL..',
    '..LWWWWWWWWWWWWWWL..',
    '..LWWWWWWWWWWWWWWL..',
    '..LLLLLLLLLLLLLLLL..',
    '...OOOOOOOOOOOOOO...',
    '...SSSSSSSSSSSSSS...',
  ];

  static const _legs = {
    'stand': [
      '.....OO......OO.....',
      '.....OO......OO.....',
      '.....SS......SS.....',
    ],
    'stepL': [
      '.....OO......OO.....',
      '.....SS......OO.....',
      '.............SS.....',
    ],
    'stepR': [
      '.....OO......OO.....',
      '.....OO......SS.....',
      '.....SS.............',
    ],
    'tuck': [
      '.....SS......SS.....',
      '....................',
      '....................',
    ],
  };

  /// The face's dark pixels, inside the screen (14 x 8, from its top
  /// left), looking [look] pixels to the right.
  static Set<(int, int)> _face(String kind, int look) {
    final eyes = [3 + look, 10 + look];
    final mouth = 4 + look;
    return {
      for (final e in eyes)
        ...kind == 'blink'
            ? [(e, 2), (e + 1, 2)]
            : [(e, 1), (e + 1, 1), (e, 2), (e + 1, 2)],
      ...kind == 'oh'
          ? [
              (mouth + 2, 4),
              (mouth + 3, 4),
              (mouth + 1, 5),
              (mouth + 4, 5),
              (mouth + 2, 6),
              (mouth + 3, 6),
            ]
          : [
              (mouth, 4),
              (mouth + 5, 4),
              for (var i = 1; i <= 4; i++) (mouth + i, 5),
            ],
    };
  }

  static List<String> _frame(String face, String legs, {int look = 0}) {
    final rows = [for (final r in _head) r.split('')];
    for (final (x, y) in _face(face, look)) {
      rows[4 + y][3 + x] = 'K';
    }
    return [
      for (final r in rows) r.join(),
      ..._legs[legs]!,
    ];
  }

  static final frames = {
    PipFrame.idle: _frame('smile', 'stand'),
    PipFrame.blink: _frame('blink', 'stand'),
    // Walking: looking ahead (to the right; mirrored going left).
    PipFrame.step1: _frame('smile', 'stepL', look: 1),
    PipFrame.step2: _frame('smile', 'stand', look: 1),
    PipFrame.step3: _frame('smile', 'stepR', look: 1),
    PipFrame.step4: _frame('smile', 'stand', look: 1),
    PipFrame.oh: _frame('oh', 'stand'),
    PipFrame.tuck: _frame('oh', 'tuck'),
  };

  static const colours = {
    'L': PipColours.casing,
    'O': PipColours.body,
    'S': PipColours.shade,
    'W': PipColours.screen,
    'K': PipColours.face,
    'A': PipColours.light,
  };

  /// How many rows a frame has.
  static int get height => _head.length + 3;
}

class _RoomPainter extends CustomPainter {
  final PipBrain brain;
  final double pixel;

  _RoomPainter(this.brain, this.pixel);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..isAntiAlias = false;
    void dot(double x, double y, Color colour, [double w = 1, double h = 1]) {
      canvas.drawRect(
        Rect.fromLTWH(x * pixel, y * pixel, w * pixel, h * pixel),
        paint..color = colour,
      );
    }

    final columns = (size.width / pixel).ceil();
    final groundTop = (PipRoom.rows - PipRoom.ground).toDouble();

    // The ground: a row of grass with lighter tufts, dirt with specks.
    for (var x = 0; x < columns; x++) {
      final h = (x * 7919) % 13; // the same tufts every time
      dot(x.toDouble(), groundTop, PipColours.grass);
      if (h < 3) dot(x.toDouble(), groundTop - 1, PipColours.grassLight);
      for (var y = 1; y < PipRoom.ground; y++) {
        final speck = (x * 31 + y * 17) % 11 == 0;
        dot(x.toDouble(), groundTop + y,
            speck ? PipColours.dirtDark : PipColours.dirt);
      }
    }

    final sprite = PipSprites.frames[brain.frame]!;
    final rows = sprite.length;
    final (sx, sy) = brain.stretch;
    final centre = brain.x + PipBrain.width / 2;
    final bottom = groundTop - brain.lift + brain.sunk;

    // Coming out of the ground: the hole and its flying dirt.
    if (brain.dirt > 0) {
      dot(centre - 7, groundTop, PipColours.dirtDark, 14, 1);
      final t = brain.dirt;
      for (var i = 0; i < 6; i++) {
        final side = i.isEven ? 1 : -1;
        final spread = (2 + i) * t * 4;
        final up = 10 * math.sin(math.pi * t) * (0.6 + 0.1 * i);
        dot(centre + side * spread, groundTop - 1 - up, PipColours.dirt);
      }
    }

    // Pip, clipped at the ground while he comes up.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, groundTop * pixel));
    final w = sx * pixel;
    final h = sy * pixel;
    for (var y = 0; y < rows; y++) {
      final row = sprite[y];
      for (var x = 0; x < row.length; x++) {
        final colour = PipSprites.colours[row[x]];
        if (colour == null) continue;
        // Mirrored when facing left; scaled about his feet's centre.
        final gx = brain.facingRight ? x : row.length - 1 - x;
        final left = centre * pixel + (gx - PipBrain.width / 2) * w;
        final top = bottom * pixel - (rows - y) * h;
        canvas.drawRect(
          Rect.fromLTWH(left, top, w, h),
          paint..color = colour,
        );
      }
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_RoomPainter old) => true;
}
