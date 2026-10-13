import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/pip_sprites.dart';

/// Pip's room (Round 26): a strip of field at the bottom of the menu where
/// Pip stands about and walks, moved by [brain]. Drawn in pixels (each a
/// whole number of the screen's), crisp at any size. With [animate] off
/// (tests, or the phone's "remove animations") he just stands there.
///
/// Before he's hatched (Round 34) it holds his egg: each tap cracks it a
/// little more, with a buzz; the last one pops him out ([onHatched]).
class PipRoom extends StatefulWidget {
  final PipBrain brain;
  final bool animate;

  /// The tap that hatched him: that moment is his birthday.
  final VoidCallback? onHatched;

  const PipRoom({
    super.key,
    required this.brain,
    this.animate = true,
    this.onHatched,
  });

  /// About how big one of Pip's pixels is.
  static const pixel = 2.5;

  /// The room's height, in Pip's pixels: Pip (19), a hop (6), the
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
    // Not moving: he's simply there, standing (out of the ground, or out
    // of his egg).
    if (!_moving) {
      switch (widget.brain.activity) {
        case PipActivity.spawning:
          widget.brain.step(PipBrain.landEnd);
        case PipActivity.hatching:
          widget.brain.step(PipBrain.fadeEnd);
        default:
      }
    }
  }

  /// A tap on his egg: a crack and a buzz; the last pops him out, with a
  /// longer buzz.
  void _tapEgg() {
    final hatched = widget.brain.tapEgg();
    if (hatched) {
      HapticFeedback.heavyImpact();
      Future<void>.delayed(
        const Duration(milliseconds: 90),
        HapticFeedback.mediumImpact,
      );
      widget.onHatched?.call();
    } else {
      HapticFeedback.lightImpact();
    }
    setState(_sync);
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
    final egg = widget.brain.activity == PipActivity.egg;
    return Semantics(
      key: const Key('pipRoom'),
      label: egg ? "Pip's egg. Tap it to hatch him" : 'Pip, in his room',
      image: !egg,
      button: egg,
      onTap: egg ? _tapEgg : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: egg ? _tapEgg : null,
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
      ),
    );
  }
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

    /// A sprite's pixels, its bottom left at [left], [bottom] (in room
    /// pixels); faded by [alpha]; upside down with [flip].
    void sprite(List<String> rows, double left, double bottom,
        {double alpha = 1, bool flip = false}) {
      for (var y = 0; y < rows.length; y++) {
        final row = rows[flip ? rows.length - 1 - y : y];
        for (var x = 0; x < row.length; x++) {
          final colour = PipSprites.colours[row[x]];
          if (colour == null) continue;
          dot(left + x, bottom - rows.length + y,
              colour.withValues(alpha: colour.a * alpha));
        }
      }
    }

    final eggLeft =
        brain.eggX + (PipBrain.width - PipSprites.egg[0].length) / 2;

    // Not hatched yet (Round 34): his egg, cracked as far as tapped.
    if (brain.activity == PipActivity.egg) {
      sprite(PipSprites.crackedEgg(brain.crack), eggLeft, groundTop);
      return;
    }
    final hatching = brain.activity == PipActivity.hatching;
    final shell = 1 - brain.shellFade;
    if (hatching) {
      // The egg's top, flying off to the right and landing upside down.
      final f = brain.capFlight;
      final top = PipSprites.eggTop;
      final landed = groundTop;
      final from = groundTop - (PipSprites.egg.length - top.length);
      final arc = 8 * math.sin(math.pi * f);
      sprite(
        top,
        eggLeft + 14 * f,
        from + (landed - from) * f - arc,
        alpha: shell,
        flip: f > 0.5,
      );
    }
    if (!brain.visible) {
      if (hatching) {
        sprite(PipSprites.eggBottom, eggLeft, groundTop, alpha: shell);
      }
      return;
    }

    final sprite0 = PipSprites.frames[brain.frame]!;
    final rows = sprite0.length;
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
      final row = sprite0[y];
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
    // The egg's bottom half in front of him, as he jumps out of it.
    if (hatching) {
      sprite(PipSprites.eggBottom, eggLeft, groundTop, alpha: shell);
    }
  }

  @override
  bool shouldRepaint(_RoomPainter old) => true;
}
