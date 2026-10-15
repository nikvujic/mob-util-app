import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/pip_sprites.dart';

/// Pip's room (Round 26): a strip of field at the bottom of the menu where
/// Pip stands about and walks, moved by [brain]. Drawn in pixels (each a
/// whole number of the screen's), crisp at any size. With [animate] off
/// (tests, or the phone's "remove animations") he just stands there.
///
/// Before he's hatched (Round 34) it holds his egg: each tap cracks it a
/// little more, with a buzz; the last one pops him out ([onHatched]).
///
/// Round 37: with a [link] to his life, he shows as it says (asleep,
/// off, falling asleep...), checked every second; his face and pace
/// follow his energy; a tap drops a battery for him, if he can have one.
class PipRoom extends StatefulWidget {
  final PipBrain brain;
  final bool animate;

  /// His life: what to show, and batteries; null: he just stands about.
  final PipLink? link;

  /// The tap that hatched him: that moment is his birthday.
  final VoidCallback? onHatched;

  /// What's in his sky (Round 35), worked out for this place and moment;
  /// null: no sky (the page's own colour behind him).
  final PipScene? scene;

  /// How tall it is, in his pixels: [rows] for the menu's strip, more for
  /// Pip Home's scene.
  final int height;

  const PipRoom({
    super.key,
    required this.brain,
    this.animate = true,
    this.onHatched,
    this.link,
    this.scene,
    this.height = rows,
    this.pixel = smallPixel,
    this.entrances = const {PipEntrance.ground},
  });

  /// How he may come in (Round 52): the menu has all three (thrown in by
  /// its swing only there), Pip Home the ground and the sky. One at
  /// random, the first time he's seen and back after a while
  /// ([PipBrain.awayFor]); not without animations (he's simply there).
  final Set<PipEntrance> entrances;

  /// About how big one of Pip's pixels is: [smallPixel] in the menu,
  /// bigger in Pip Home.
  final double pixel;
  static const smallPixel = 2.5;

  /// The menu room's height, in Pip's pixels (Round 36: twice the first
  /// one's 32): Pip (19), a hop, the ground (5) and his sky.
  static const rows = 64;

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
    // His life checked every second (Round 37).
    _sinceCheck += dt;
    if (_sinceCheck >= 1) {
      _sinceCheck = 0;
      _check();
    }
    // A long pause (e.g. the app away) doesn't jump him across the room.
    setState(() => widget.brain.step(dt.clamp(0, 0.1)));
    // Round 53: a buzz where something hits (a landing, a strike, a kick).
    for (final buzz in widget.brain.takeBuzzes()) {
      switch (buzz) {
        case PipBuzz.light:
          HapticFeedback.lightImpact();
        case PipBuzz.medium:
          HapticFeedback.mediumImpact();
        case PipBuzz.heavy:
          HapticFeedback.heavyImpact();
      }
    }
  }

  double _sinceCheck = 0;

  /// Whether his way in was picked (once a room's time).
  bool _entered = false;

  /// When his life was last looked at (notifications since then).
  DateTime? _lastLook;

  PipEntrance _pickEntrance() {
    final ways = widget.entrances.toList();
    return ways[widget.brain.random.nextInt(ways.length)];
  }

  /// What was last made so from his life; null: nothing yet.
  PipShow? _shown;

  /// Asks his life what to show and makes it so (once a change, not over
  /// and over, so a demo from Pip Home's list isn't undone); also his
  /// energy for his face and pace. Never during a build: it may collect
  /// a battery.
  void _check() {
    final link = widget.link;
    final brain = widget.brain;
    if (link == null || !mounted) return;
    if (brain.activity == PipActivity.egg ||
        brain.activity == PipActivity.hatching) {
      return;
    }
    final (show, segments) = link.look();
    brain.segments = segments;
    final now = link.now;
    // Round 52: his way in, the first time or back after a while.
    if (_moving && show == PipShow.awake && !_entered) {
      _entered = true;
      final left = brain.leftAt;
      final back = left != null &&
          now.difference(left) >= PipBrain.awayFor &&
          (brain.activity == PipActivity.standing ||
              brain.activity == PipActivity.walking);
      if (brain.freshSpawn || back) brain.enter(_pickEntrance());
    }
    // A notification came since the last look: his screen shows it.
    final since = _lastLook;
    if (since != null && link.notifiedBetween(since, now)) brain.notify();
    _lastLook = now;
    // Round 53: a medicine due, he reminds; a recipe read within the
    // hour, he eats (once for it).
    brain.medicineDue = link.medicineDue;
    // Round 57: a birthday, the party hat.
    brain.birthday = link.partyHat;
    final read = link.recipeReadAt;
    if (_moving &&
        read != null &&
        read != brain.ateFor &&
        !now.isBefore(read) &&
        now.difference(read) < PipBrain.eatsWithin &&
        brain.eat()) {
      brain.ateFor = read;
    }
    // Round 44: plugged in or out; seen happening only once he's been
    // looked at (opened while charging, he's simply there, charging).
    brain.setPlugged(link.plugged, animate: _shown != null && _moving);
    if (show != _shown && brain.show(show)) {
      _shown = show;
      link.shown(show);
    }
    if (!_moving) _finish();
  }

  void _checkSoon() => WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        setState(_check);
      });

  bool get _moving =>
      widget.animate &&
      !(MediaQuery.maybeDisableAnimationsOf(context) ?? false);

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
    _checkSoon();
  }

  @override
  void didUpdateWidget(PipRoom old) {
    super.didUpdateWidget(old);
    _sync();
    if (!_moving) _checkSoon();
  }

  void _sync() {
    if (_moving && !_ticker.isActive) {
      _last = Duration.zero;
      _ticker.start();
    } else if (!_moving && _ticker.isActive) {
      _ticker.stop();
    }
    if (!_moving) _finish();
  }

  /// Not moving: whatever he's doing is simply done (out of the ground
  /// or his egg, asleep, off, back on, a battery picked up).
  void _finish() {
    final brain = widget.brain;
    for (var i = 0; i < 6; i++) {
      // Round 55: his medicine reminder has no end: the pill just shows.
      if (brain.reminding) return;
      switch (brain.activity) {
        case PipActivity.spawning:
          brain.step(PipBrain.landEnd);
        case PipActivity.hatching:
          brain.step(PipBrain.fadeEnd);
        case PipActivity.fallingAsleep:
          brain.step(PipBrain.asleepEnd);
        case PipActivity.wakingUp:
          brain.step(PipBrain.wakeHopEnd);
        case PipActivity.poweringOff:
          brain.step(PipBrain.offEnd);
        case PipActivity.poweringOn:
          brain.step(PipBrain.onEnd);
        case PipActivity.fetching ||
              PipActivity.toStation ||
              PipActivity.plugging ||
              PipActivity.unplugging ||
              // Round 52: an entrance or an event, run to its end.
              PipActivity.falling ||
              PipActivity.thrown ||
              PipActivity.angry ||
              PipActivity.bugHunt ||
              PipActivity.showing ||
              PipActivity.flower ||
              PipActivity.butterfly ||
              PipActivity.ball ||
              PipActivity.stargazing ||
              PipActivity.dancing ||
              PipActivity.eating:
          // Walking over, then picking it up (or plugging in or out).
          final doing = brain.activity;
          for (var s = 0; s < 1200 && brain.activity == doing; s++) {
            brain.step(0.05);
          }
          brain.takeBuzzes(); // run past unseen: no buzzes for it
        default:
          // The station up or gone at once (Round 44), and whatever he
          // then does (off to plug in) done too.
          if (!brain.stationMoving) return;
          brain.step(PipBrain.stationRise);
      }
    }
  }

  /// A tap in his room (Round 37): a battery for him, dropped there, if
  /// he can have one now; a light buzz if not.
  void _tapRoom(double atPixel) {
    final link = widget.link;
    final brain = widget.brain;
    if (link == null) return;
    if (brain.canTakeBattery && link.giveBattery()) {
      brain.takeBattery(atPixel - PipBrain.batteryWidth / 2);
      HapticFeedback.mediumImpact();
      _shown = null; // his energy changed: look again
      setState(_sync);
      _checkSoon();
    } else {
      HapticFeedback.selectionClick();
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
    // Round 52: when he was left, for coming back in after a while.
    final link = widget.link;
    if (link != null) widget.brain.leftAt = link.now;
    _ticker.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.devicePixelRatioOf(context);
    // Whole device pixels a room pixel.
    final pixel = math.max(1.0, (widget.pixel * ratio).floorToDouble()) / ratio;
    final egg = widget.brain.activity == PipActivity.egg;
    final feeds = !egg && widget.link != null;
    return Semantics(
      key: const Key('pipRoom'),
      label: egg
          ? "Pip's egg. Tap it to hatch him"
          : feeds
              ? 'Pip, in his room. Tap to give him a battery'
              : 'Pip, in his room',
      image: !egg && !feeds,
      button: egg || feeds,
      onTap: egg
          ? _tapEgg
          : feeds
              ? () => _tapRoom(widget.brain.roomWidth / 2)
              : null,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        // Its taps are told to screen readers above, with what they do.
        excludeFromSemantics: true,
        onTap: egg ? _tapEgg : null,
        onTapUp: feeds ? (d) => _tapRoom(d.localPosition.dx / pixel) : null,
        child: LayoutBuilder(
          builder: (context, box) {
            widget.brain.roomWidth = (box.maxWidth / pixel).floor();
            widget.brain.skyRows = widget.height - PipRoom.ground;
            widget.brain.dark = widget.scene?.part == DayPart.night ||
                widget.scene?.part == DayPart.dusk;
            return SizedBox(
              width: box.maxWidth,
              height: widget.height * pixel,
              child: CustomPaint(
                painter: _RoomPainter(
                  widget.brain,
                  pixel,
                  widget.height,
                  widget.scene,
                ),
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

  final int height;
  final PipScene? scene;

  _RoomPainter(this.brain, this.pixel, this.height, this.scene);

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

    /// A round blob of [r] pixels around [cx], [cy] (the sun, the moon).
    void disc(int cx, int cy, int r, Color colour) {
      for (var y = -r; y <= r; y++) {
        for (var x = -r; x <= r; x++) {
          if (x * x + y * y <= r * r + r) {
            dot((cx + x).toDouble(), (cy + y).toDouble(), colour);
          }
        }
      }
    }

    /// The moon in [phase] (Round 38): pale grey with darker seas, only
    /// its lit part drawn: a thin sliver, half, or all of it; growing,
    /// lit on the right. Round 52: seas in two greys and a few craters,
    /// placed by its size.
    void moon(int cx, int cy, int r, MoonPhase phase) {
      final seas = <(int, int)>{};
      final craters = <(int, int)>{};
      for (final (sx, sy, dark) in const [
        (-0.45, -0.25, false),
        (-0.25, -0.25, false),
        (-0.45, 0.0, false),
        (-0.2, 0.05, true),
        (0.25, 0.45, false),
        (0.45, 0.25, false),
        (0.45, 0.45, true),
        (0.1, -0.55, true),
        (-0.1, 0.55, false),
      ]) {
        final at = ((sx * r).round(), (sy * r).round());
        (dark ? craters : seas).add(at);
      }
      for (var y = -r; y <= r; y++) {
        for (var x = -r; x <= r; x++) {
          if (x * x + y * y > r * r + r) continue;
          // From the lit side: x > 0 growing, x < 0 shrinking.
          final side = phase.growing ? x : -x;
          final lit = switch (phase) {
            MoonPhase.none => false,
            MoonPhase.full => true,
            MoonPhase.halfGrowing || MoonPhase.halfShrinking => side >= 0,
            // Outside a shadow disc a little to the dark side.
            MoonPhase.thinGrowing ||
            MoonPhase.thinShrinking =>
              (side + r * 0.55) * (side + r * 0.55) + y * y > r * r + r,
          };
          if (!lit) continue;
          dot(
              (cx + x).toDouble(),
              (cy + y).toDouble(),
              craters.contains((x, y))
                  ? PipColours.moonDark
                  : seas.contains((x, y))
                      ? PipColours.moonShade
                      : PipColours.moon);
        }
      }
    }

    /// A pixel cloud (Round 52: three shapes, lit on top and shaded
    /// underneath; warm at dawn and dusk), its top left at [x], [y].
    void cloud(double x, double y, int shape, DayPart part) {
      const shapes = [
        [
          '...lll.....',
          '..lcccll...',
          '.lcccccclll',
          'cccccccccccc',
          '.ssssssssss.'
        ],
        [
          '......ll.......',
          '....llcccl.ll..',
          '..llcccccccccl.',
          '.cccccccccccccc',
          'ccccccccccccccc',
          '.sssssssssssss.',
        ],
        ['..ll...', '.lccll.', 'cccccc.', '.ssss..'],
      ];
      final warm = part == DayPart.dawn || part == DayPart.dusk;
      final colours = {
        'l': PipColours.cloudLight,
        'c': warm ? PipColours.cloudWarm : PipColours.cloud,
        's': warm ? PipColours.cloudWarmShade : PipColours.cloudShade,
      };
      final rows = shapes[shape % shapes.length];
      for (var j = 0; j < rows.length; j++) {
        for (var i = 0; i < rows[j].length; i++) {
          final colour = colours[rows[j][i]];
          if (colour != null) dot(x + i, y + j, colour);
        }
      }
    }

    final groundTop = (height - PipRoom.ground).toDouble();

    // His sky (Round 35): bands of colour from top to bottom (stepped,
    // pixel style), then what's in it now. Round 52: through more hues
    // (the scene's stops), more and thinner bands, each edge dithered.
    if (scene case final scene? when scene.skyStops != null) {
      final stops = scene.skyStops!;
      Color colourAt(double p) {
        final f = p.clamp(0.0, 1.0) * (stops.length - 1);
        final i = f.floor().clamp(0, stops.length - 2);
        return Color.lerp(stops[i], stops[i + 1], f - i)!;
      }

      final bands = (groundTop / 4).round().clamp(8, 28);
      final band = groundTop / bands;
      for (var i = 0; i < bands; i++) {
        final top = (i * band).floorToDouble();
        final bottom = ((i + 1) * band).floorToDouble();
        final colour = colourAt(i / (bands - 1));
        dot(0, top, colour, columns.toDouble(), bottom - top);
        // The edge above: every other pixel of this band's colour.
        if (i > 0) {
          for (var x = i % 2; x < columns; x += 2) {
            dot(x.toDouble(), top - 1, colour);
          }
        }
      }
      // A tall sky gets the bigger sun and moon.
      final home = groundTop > 40;
      // The sun's or moon's place: high on the right (Round 52: the sun
      // low and orange at dawn).
      final bodyX = columns - (home ? 16 : 10);
      final dawn = scene.part == DayPart.dawn;
      final bodyY = (home ? 11 : 6) + (dawn ? (home ? 8 : 4) : 0);
      final bodyR = home ? 6 : 4;
      // The sky behind the sun or moon, for their glow (blended, so it
      // isn't grey over a coloured sky).
      final behind = colourAt(bodyY / groundTop);
      for (final prop in scene.props) {
        switch (prop) {
          case PipProp.stars:
            // The same stars every time (Round 38: fewer, most of them
            // dim, a few bright with a twinkle; Round 52: some warm,
            // some cool), in the upper sky and clear of the moon.
            final top = (groundTop * 0.7).floor();
            for (var i = 0; i < columns * top ~/ 130; i++) {
              final h = _hash(i);
              final x = h % columns;
              final y = (h ~/ columns) % top;
              final dx = x - bodyX, dy = y - bodyY;
              if (dx * dx + dy * dy < (bodyR + 5) * (bodyR + 5)) continue;
              final bright = i % 6 == 0;
              final colour = bright
                  ? PipColours.star
                  : i % 7 == 0
                      ? PipColours.starWarm
                      : i % 11 == 0
                          ? PipColours.starCool
                          : PipColours.starDim;
              dot(x.toDouble(), y.toDouble(), colour);
              if (bright && i % 12 == 0) {
                for (final (ox, oy) in [(-1, 0), (1, 0), (0, -1), (0, 1)]) {
                  dot((x + ox).toDouble(), (y + oy).toDouble(),
                      PipColours.starDim);
                }
              }
            }
          case PipProp.moon:
            // A faint halo at night, then the moon.
            if (scene.part == DayPart.night && scene.moon != MoonPhase.none) {
              disc(bodyX, bodyY, bodyR + 3,
                  Color.lerp(behind, PipColours.moon, 0.12)!);
            }
            moon(bodyX, bodyY, bodyR, scene.moon);
          case PipProp.sun:
            // A round sun with rays (Round 38: unlike the moon); Round 52:
            // a glow round it, long and short rays, a bright core.
            final face = dawn ? PipColours.sunLow : PipColours.sun;
            disc(bodyX, bodyY, bodyR + 2, Color.lerp(behind, face, 0.35)!);
            disc(bodyX, bodyY, bodyR - 1, face);
            final ray = bodyR + 1;
            for (final (ox, oy) in [(0, 1), (0, -1), (1, 0), (-1, 0)]) {
              for (var k = 0; k < (home ? 3 : 2); k++) {
                dot((bodyX + ox * (ray + k)).toDouble(),
                    (bodyY + oy * (ray + k)).toDouble(), face);
              }
            }
            final diagonal = (ray * 0.75).round();
            for (final (ox, oy) in [(1, 1), (1, -1), (-1, 1), (-1, -1)]) {
              dot((bodyX + ox * diagonal).toDouble(),
                  (bodyY + oy * diagonal).toDouble(), face);
              if (home) {
                dot((bodyX + ox * (diagonal + 1)).toDouble(),
                    (bodyY + oy * (diagonal + 1)).toDouble(), face);
              }
            }
            final core = (bodyR / 3).ceil();
            disc(bodyX - 1, bodyY - 1, core, PipColours.sunCore);
          case PipProp.clouds:
            final spots = home
                ? const [
                    (0.08, 0.18),
                    (0.36, 0.08),
                    (0.55, 0.3),
                    (0.78, 0.45),
                    (0.2, 0.5),
                  ]
                : const [(0.15, 0.25), (0.55, 0.12), (0.8, 0.35)];
            for (final (i, (cx, cy)) in spots.indexed) {
              cloud((columns * cx).floorToDouble(),
                  (groundTop * cy).floorToDouble(), i, scene.part);
            }
        }
      }
    }

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
    /// pixels); faded by [alpha]; upside down with [flip]; mirrored with
    /// [mirror]; in [colours] (his own by default).
    void sprite(List<String> rows, double left, double bottom,
        {double alpha = 1,
        bool flip = false,
        bool mirror = false,
        Map<String, Color> colours = PipSprites.colours}) {
      for (var y = 0; y < rows.length; y++) {
        final row = rows[flip ? rows.length - 1 - y : y];
        for (var x = 0; x < row.length; x++) {
          final colour = colours[row[mirror ? row.length - 1 - x : x]];
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

    // Round 44: his charging station, rising out of the ground (clipped
    // there), its socket facing him; the cable from it to the plug.
    if (brain.station case (final sx, final up, final right)) {
      canvas.save();
      canvas.clipRect(Rect.fromLTWH(0, 0, size.width, groundTop * pixel));
      sprite(
        brain.stationLamp ? PipSprites.station : PipSprites.stationLampOff,
        sx,
        groundTop + (1 - up) * PipBrain.stationHeight,
        mirror: !right,
        colours: PipSprites.stationColours,
      );
      canvas.restore();
      if (up >= 1) {
        if (brain.plug case (final px, final py)) {
          final (cx, cy) = brain.socket;
          // From the socket to the plug's end that faces the station.
          final endX = right ? px + 1 : px;
          _line(dot, cx, groundTop - cy - 1, endX, groundTop - py - 1,
              PipColours.cable);
          sprite(PipSprites.plug, px, groundTop - py);
        }
      }
    }

    final sprite0 = pipFrameOf(brain);
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

    // A battery dropped in his room, or flying to him (Round 37).
    if (brain.battery case (final left, final up)) {
      sprite(PipSprites.battery, left, groundTop - up);
    }
    // Round 54: his old one, pulled out of his side (behind his casing
    // till it's out) and thrown away, end over end, fading.
    if (brain.oldBattery
        case (final left, final up, final faded, final turned)) {
      sprite(PipSprites.batteryEmpty, left.floorToDouble(),
          (groundTop - up).floorToDouble(),
          alpha: 1 - faded, flip: turned);
    }

    // Round 52: what's in his field, behind him. A flower coming up
    // (only its grown part shows), or still in the ground.
    if (brain.flower case (final fx, final up, final grown, final fade)
        when up == 0) {
      final rows = PipSprites.flower;
      final shown = (rows.length * grown).ceil();
      sprite(rows.sublist(rows.length - shown), fx - 2, groundTop,
          colours: PipSprites.fieldColours, alpha: 1 - fade);
    }
    // A bug crawling in, its legs stepping; mirrored going right.
    if (brain.bug case (final bx, final legsUp)) {
      final toRight = bx + PipBrain.bugWidth / 2 < centre;
      sprite(legsUp ? PipSprites.bugUp : PipSprites.bugDown, bx, groundTop,
          colours: PipSprites.fieldColours, mirror: toRight);
    }
    // A ball, rolling (its stripe turning) or bouncing off.
    if (brain.ball case (final bx, final up, final turn)) {
      sprite(PipSprites.ballFrames[turn], bx, groundTop - up,
          colours: PipSprites.fieldColours);
    }

    // Pip, clipped at the ground while he comes up.
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, size.width, groundTop * pixel));
    // Falling over (Round 37): turned about the bottom corner of his
    // casing on the side he falls to.
    if (brain.tilt > 0) {
      final right = brain.fallRight;
      final pivot = Offset(
        (brain.x + (right ? 18 : 2)) * pixel,
        groundTop * pixel,
      );
      canvas.translate(pivot.dx, pivot.dy);
      canvas.rotate((right ? 1 : -1) * brain.tilt * math.pi / 2);
      canvas.translate(-pivot.dx, -pivot.dy);
    }
    // Thrown in (Round 52): tumbling about his middle.
    if (brain.spin != 0) {
      final mid = Offset(centre * pixel, (bottom - rows / 2) * pixel);
      canvas.translate(mid.dx, mid.dy);
      canvas.rotate(brain.spin);
      canvas.translate(-mid.dx, -mid.dy);
    }
    final w = sx * pixel;
    final h = sy * pixel;

    /// A pixel of his at [x], [y] on his frame (rows may run above it:
    /// his hat): mirrored when facing left, scaled about his feet.
    void own(int x, int y, Color colour) {
      final gx = brain.facingRight ? x : PipBrain.width - 1 - x;
      final left = centre * pixel + (gx - PipBrain.width / 2) * w;
      final top = bottom * pixel - (rows - y) * h;
      canvas.drawRect(Rect.fromLTWH(left, top, w, h), paint..color = colour);
    }

    for (var y = 0; y < rows; y++) {
      final row = sprite0[y];
      for (var x = 0; x < row.length; x++) {
        final colour = PipSprites.colours[row[x]];
        if (colour != null) own(x, y, colour);
      }
    }
    // Round 57: his hat, on his head: moved with him whatever he does.
    if (brain.hat case final hat? when !brain.hatBeside) {
      final art = PipSprites.hats[hat]!;
      final top = PipSprites.hatBottom - art.length + 1;
      for (var y = 0; y < art.length; y++) {
        for (var x = 0; x < art[y].length; x++) {
          final colour = PipSprites.hatColours[art[y][x]];
          if (colour != null) own(PipSprites.hatLeft + x, top + y, colour);
        }
      }
    }
    canvas.restore();
    // Asleep, it's on the ground beside him (on the side with room).
    if (brain.hat case final hat? when brain.hatBeside) {
      final art = PipSprites.hats[hat]!;
      final right = brain.x + PipBrain.width + 1;
      sprite(
        art,
        right + art.first.length <= size.width / pixel
            ? right
            : brain.x - art.first.length - 1,
        groundTop,
        colours: PipSprites.hatColours,
      );
    }
    // Round 54: the slot in his side, open while his battery's changed.
    // Scaled with him, as he crouches.
    if (brain.batterySlot case final column?) {
      final (sx, sy) = brain.stretch;
      dot(
          centre + (column - centre) * sx,
          bottom - (PipBrain.slotUp + PipBrain.slotRows) * sy,
          PipColours.cable,
          sx,
          PipBrain.slotRows * sy);
    }
    // Round 53: his plate, its meal, crumbs falling (his hands on it
    // next).
    if (brain.plate case (final px, final py, final taken, final size)
        when size > 0.05) {
      final bottom = (groundTop - py).floorToDouble();
      sprite(PipSprites.plate, px.floorToDouble(), bottom,
          colours: PipSprites.fieldColours, alpha: size);
      sprite(PipSprites.meal(PipBrain.bites.length - taken), px.floorToDouble(),
          bottom - PipSprites.plate.length,
          colours: PipSprites.fieldColours, alpha: size);
    }
    for (final (cx, cy) in brain.crumbs) {
      dot(cx.floorToDouble(), (groundTop - cy).floorToDouble(),
          PipColours.meal);
    }
    // His hands (Round 44), popping in and away (a sparkle as they do).
    for (final (mx, my, size) in brain.mitts) {
      if (size <= 0.05) continue;
      final w = PipSprites.mitt[0].length * size;
      final h = PipSprites.mitt.length * size;
      final cx = mx + 1, cy = groundTop - my - 1.5;
      for (var y = 0; y < PipSprites.mitt.length; y++) {
        for (var x = 0; x < PipSprites.mitt[y].length; x++) {
          final colour = PipSprites.colours[PipSprites.mitt[y][x]]!;
          dot(cx - w / 2 + x * size, cy - h / 2 + y * size, colour, size, size);
        }
      }
      if (size < 1) {
        final out = 1 + 2 * (1 - size);
        for (final (ox, oy) in const [(-1, -1), (1, -1), (-1, 1), (1, 1)]) {
          dot((cx + ox * (out + 0.5)).floorToDouble(),
              (cy + oy * (out + 0.5)).floorToDouble(), PipColours.stationBolt);
        }
      }
    }
    // Round 52: in front of him.
    // Dust puffing up either side where he landed.
    if (brain.landingDust case final t?) {
      for (var i = 0; i < 4; i++) {
        final side = i.isEven ? 1 : -1;
        final out = PipBrain.width / 2 + 1 + (2 + i) * t * 3;
        final up = 4 * math.sin(math.pi * t) * (1 - i * 0.15);
        dot((centre + side * out).floorToDouble(),
            (groundTop - 1 - up).floorToDouble(), PipColours.puff);
      }
    }
    // A bug struck: a poof.
    if (brain.poof case (final px, final t)) {
      final out = 1 + 4 * t;
      for (final (ox, oy) in const [
        (-1, -1),
        (1, -1),
        (-1, 1),
        (1, 1),
        (0, -1),
        (-1, 0),
        (1, 0),
      ]) {
        dot((px + ox * out).floorToDouble(),
            (groundTop - 2 + oy * out * 0.7).floorToDouble(), PipColours.puff);
      }
    }
    // His sword, in a floating hand: raised, swung, popping in and away.
    if (brain.sword case (final hx, final hy, final angle, final size)
        when size > 0.05) {
      final hand = Offset(hx * pixel, (groundTop - hy) * pixel);
      canvas.save();
      canvas.translate(hand.dx, hand.dy);
      canvas.rotate(angle);
      canvas.scale(size);
      final blade = PipSprites.sword;
      for (var y = 0; y < blade.length; y++) {
        for (var x = 0; x < blade[y].length; x++) {
          final colour = PipSprites.fieldColours[blade[y][x]];
          if (colour == null) continue;
          // The middle of the grip in the hand.
          canvas.drawRect(
            Rect.fromLTWH((x - blade[y].length / 2) * pixel,
                (y - PipSprites.swordGrip - 0.5) * pixel, pixel, pixel),
            paint..color = colour,
          );
        }
      }
      canvas.restore();
      sprite(PipSprites.mitt, hx - 1, groundTop - hy + 2);
    }
    // A flower in his hand, then fading.
    if (brain.flower case (final fx, final up, _, final fade) when up > 0) {
      sprite(PipSprites.flower, fx - 1, groundTop - up,
          colours: PipSprites.fieldColours, alpha: 1 - fade);
    }
    if (brain.flowerHand case (final hx, final hy)) {
      sprite(PipSprites.mitt, hx, groundTop - hy + 3);
    }
    // Angry: a fist shaking over his head, cross words above.
    if (brain.fist case (final fx, final fy)) {
      sprite(PipSprites.mitt, fx, groundTop - fy);
      final words = PipSprites.crossWords[(brain.zsClock * 4).floor() % 2];
      // Round 53: lower, just over his head beside his antenna, away
      // from the fist.
      sprite(words, brain.facingRight ? centre - 10 : centre + 3,
          groundTop - PipBrain.height + 1,
          colours: PipSprites.fieldColours);
    }
    // A shooting star: its head and a fading tail.
    if (brain.shootingStar case (final sx, final sy, _)) {
      final back = brain.shootingStarFromLeft ? -1 : 1;
      dot(sx.floorToDouble(), sy.floorToDouble() - 1, PipColours.star, 2, 2);
      for (var i = 1; i < 14; i++) {
        dot(
            (sx + back * i).floorToDouble(),
            (sy - i * 0.35).floorToDouble(),
            Color.lerp(PipColours.star, PipColours.starWarm, i / 14)!
                .withValues(alpha: 1 - i / 16));
      }
    }
    // A butterfly fluttering by.
    if (brain.butterfly case (final bx, final up, final wingsUp)) {
      sprite(wingsUp ? PipSprites.butterflyUp : PipSprites.butterflyDown, bx,
          groundTop - up,
          colours: PipSprites.fieldColours);
    }
    for (final (x, up) in brain.sparks) {
      dot(x.floorToDouble(), (groundTop - up - 1).floorToDouble(),
          PipColours.stationBolt);
    }
    // Humming: notes floating up, fading.
    for (final (dx, up, fade) in brain.notes) {
      sprite(PipSprites.note, centre + dx, groundTop - 18 - up,
          alpha: 1 - fade);
    }
    // Asleep: little z's rising above his head, fading.
    for (final (dx, up, fade) in brain.zs) {
      sprite(PipSprites.z, centre + dx, groundTop - 18 - up, alpha: 1 - fade);
    }
    // The egg's bottom half in front of him, as he jumps out of it.
    if (hatching) {
      sprite(PipSprites.eggBottom, eggLeft, groundTop, alpha: shell);
    }
  }

  @override
  bool shouldRepaint(_RoomPainter old) => true;
}

/// A line of pixels from [x0], [y0] to [x1], [y1] (the cable).
void _line(void Function(double, double, Color) dot, double x0, double y0,
    double x1, double y1, Color colour) {
  final steps = math.max((x1 - x0).abs(), (y1 - y0).abs()).ceil();
  for (var i = 0; i <= steps; i++) {
    final p = steps == 0 ? 0.0 : i / steps;
    dot((x0 + (x1 - x0) * p).roundToDouble(),
        (y0 + (y1 - y0) * p).roundToDouble(), colour);
  }
}

/// A well-mixed number for [i], so the stars scatter without lines.
int _hash(int i) {
  var h = (i + 1) * 0x9E3779B1;
  h = (h ^ (h >> 15)) * 0x85EBCA77;
  h = h ^ (h >> 13);
  return h & 0x7FFFFFFF;
}

/// His frame now, as drawn before mirroring (facing left): his body and
/// face, or a picture on his screen (charging, Round 44; something to
/// show, Round 52). A picture is turned first when he faces left, so it
/// reads the right way drawn mirrored (Round 53: notifications; Round 57:
/// all of them, the charging ones too: the bolt, the battery).
List<String> pipFrameOf(PipBrain brain) {
  final charge = brain.chargeScreen;
  final shown = brain.screenShow;
  final picture = charge != null
      ? PipSprites.chargingFrame(charge.$1, charge.$2, lamp: brain.stationLamp)
      : shown != null
          ? PipSprites.screenFrame(shown.$1, shown.$2)
          : null;
  if (picture == null) return PipSprites.frameOf(brain.frame, brain.face);
  return brain.facingRight ? picture : PipSprites.screenTurned(picture);
}
