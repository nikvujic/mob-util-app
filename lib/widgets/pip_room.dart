import 'dart:math' as math;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_bus.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/core/pip_run.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/core/weather.dart';
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
    _charge(dt.clamp(0, 0.1));
    // Round 73: bugs struck down, watched: his XP shown collects what
    // he's gained (a boss brings more), rising over where it was.
    for (final foe in widget.brain.takeDefeats()) {
      final xp = widget.link?.defeated(boss: foe == PipFoe.boss) ?? 0;
      if (xp > 0) widget.brain.showXp(xp);
    }
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

  /// Seconds at his station, watched, since the last segment it gave.
  double _charging = 0;

  /// Round 58: his station's charge reaches his life: a segment every
  /// [PipBrain.chargeEvery] he's at it while watched, and the drone's
  /// when he was off. His icon shows it at once.
  void _charge(double dt) {
    final link = widget.link;
    final brain = widget.brain;
    if (link == null) return;
    var charged = false;
    if (brain.activity == PipActivity.charging) {
      _charging += dt;
      if (_charging >= PipBrain.chargeEvery) {
        _charging = 0;
        charged = link.chargeTick();
      }
    } else {
      _charging = 0;
    }
    if (brain.takeDroneCharge()) charged = link.chargeTick() || charged;
    if (charged) brain.segments = link.look().$2;
  }

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

  /// His adventure level when last looked at (Round 63).
  int? _level;

  /// Whether the phone's plugged in was known at an earlier look.
  bool _pluggedKnown = false;

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
    // Round 63: out on his adventure (looked at: his break may start).
    final out = link.outing();
    // Round 52: his way in, the first time or back after a while (not
    // while he's out: he's simply there, running).
    if (out != null) _entered = true;
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
    // Round 61: otherwise today's (a day of the year's, or a random one).
    brain.dayHat = link.hatToday;
    // Round 67: his ski trip: snow, skiing for his day out.
    final trip = link.trip();
    brain.snowy = trip.snowy;
    brain.skiing = trip.skiing;
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
    final seen = _shown != null && _moving;
    // Round 63: out, he doesn't charge (at 12:00 he unplugs and goes).
    // Round 64: not till Android has said (the first time, simply so).
    if (link.plugged case final plugged?) {
      brain.setPlugged(plugged && out == null && trip.leg == null,
          animate: seen && _pluggedKnown);
      _pluggedKnown = true;
    }
    // Round 67: on his ski trip's bus.
    brain.ride(trip, animate: seen);
    brain.adventure(out, animate: seen);
    // Round 74: his field's trees go by with his time out, alike here and
    // in the other room.
    brain.syncOutRun(out == null ? null : link.outRun(),
        paused: out?.onBreak ?? false);
    // Round 73: watched fighting, his XP shown goes up only as he strikes
    // bugs; a boss may come if none was beaten today.
    brain.bossDue = link.bossDue;
    link.fighting(_moving && brain.fighting);
    // A level up seen while he's out: a flash over him.
    final level = link.level;
    final before = _level;
    if (before != null && level > before && brain.run != null && _moving) {
      brain.levelUp();
    }
    _level = level;
    if (show != _shown && brain.show(show)) {
      _shown = show;
      link.shown(show);
    }
    if (!_moving) {
      _finish();
      // Off, plugged in, not moving: the drone's charge simply done.
      if (brain.sendDrone(animate: false)) _finish();
      _charge(0);
    }
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
        case PipActivity.adventuring:
          // Round 63: out, whatever he's in the middle of done: simply
          // running (or at the table).
          final run = brain.run!;
          for (var s = 0;
              s < 400 &&
                  run.phase != RunPhase.running &&
                  run.phase != RunPhase.sitting &&
                  brain.run != null;
              s++) {
            brain.step(0.05);
          }
          brain.takeBuzzes();
          return;
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
            final scene = widget.scene;
            widget.brain.dark =
                scene?.part == DayPart.night || scene?.part == DayPart.dusk;
            widget.brain.overcast = scene?.grey ?? false;
            widget.brain.bleak = scene != null &&
                (scene.season == Season.winter ||
                    scene.props.contains(PipProp.rain) ||
                    scene.props.contains(PipProp.snowfall));
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

    /// Round 70: [rows] drawn in [colours], top left at [left], [top].
    void pixels(List<String> rows, double left, double top,
        Map<String, Color> colours) {
      for (var y = 0; y < rows.length; y++) {
        for (var x = 0; x < rows[y].length; x++) {
          final colour = colours[rows[y][x]];
          if (colour != null) dot(left + x, top + y, colour);
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
    void cloud(double x, double y, int shape, DayPart part,
        {bool grey = false}) {
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
      final night = part == DayPart.night;
      // Round 70: grey under a grey sky, dark ones at night.
      final colours = grey
          ? {
              'l': night
                  ? PipColours.cloudNightLight
                  : PipColours.cloudGreyLight,
              'c': night ? PipColours.cloudNight : PipColours.cloudGrey,
              's': night
                  ? PipColours.cloudNightShade
                  : PipColours.cloudGreyShade,
            }
          : {
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
            // Round 61: no halo (it read as a dark ring round it).
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
            final spots = [
              ...home
                  ? const [
                      (0.08, 0.18),
                      (0.36, 0.08),
                      (0.55, 0.3),
                      (0.78, 0.45),
                      (0.2, 0.5),
                    ]
                  : const [(0.15, 0.25), (0.55, 0.12), (0.8, 0.35)],
              // Round 70: more under a grey sky, or a few more clouds.
              if (scene.grey || scene.weather == WeatherKind.partlyCloudy)
                ...home
                    ? const [
                        (0.0, 0.05),
                        (0.27, 0.28),
                        (0.48, 0.02),
                        (0.66, 0.15),
                        (0.9, 0.08),
                        (0.42, 0.42),
                      ]
                    : const [(0.0, 0.05), (0.35, 0.3), (0.68, 0.02)],
            ];
            // Round 63: out, they drift slowly back as he runs; Round 70:
            // and drift by anyway, slowly.
            final drift =
                (brain.run?.shift ?? 0) * 0.12 + brain.sceneClock * 0.4;
            for (final (i, (cx, cy)) in spots.indexed) {
              final wide = columns + 24;
              final at = ((columns * cx - drift) % wide + wide) % wide - 12;
              cloud(at.floorToDouble(), (groundTop * cy).floorToDouble(), i,
                  scene.part,
                  grey: scene.grey);
            }
          case PipProp.bats:
            // Round 70: Halloween's bats, flapping across.
            final t = brain.sceneClock;
            for (var i = 0; i < (home ? 3 : 2); i++) {
              final wide = columns + 14;
              final bx = (columns * i / 3 + t * (6 + 3 * i)) % wide - 7;
              final by =
                  groundTop * (0.18 + 0.13 * i) + 2 * math.sin(t * 2 + i);
              pixels(
                  (t * 5 + i).floor().isEven
                      ? PipSprites.batUp
                      : PipSprites.batDown,
                  bx.floorToDouble(),
                  by.floorToDouble(),
                  const {'b': PipColours.bat});
            }
          case PipProp.fireworks:
            // Round 70: New Year's Eve: rockets up, bursts, fading.
            final t = brain.sceneClock;
            const colours = [
              PipColours.lightRed,
              PipColours.lightGold,
              PipColours.lightBlue,
              PipColours.lightGreen,
            ];
            for (var k = 0; k < 3; k++) {
              const period = 2.4;
              final local = t + k * 0.8;
              final cycle = (local / period).floor();
              final p = (local % period) / period;
              final h = _hash(cycle * 3 + k);
              final cx = (10 + h % math.max(1, columns - 20)).toDouble();
              final cy = (groundTop * (0.12 + 0.1 * (h % 3))).floorToDouble();
              if (p < 0.25) {
                final y = groundTop - (groundTop - cy) * (p / 0.25);
                dot(cx, y.floorToDouble(), PipColours.lightGold);
              } else {
                final q = (p - 0.25) / 0.75;
                final r = q * (home ? 11 : 8);
                final colour =
                    colours[(h ~/ 3) % colours.length].withValues(alpha: 1 - q);
                for (var a = 0; a < 12; a++) {
                  final angle = a * math.pi / 6;
                  dot(
                      (cx + math.cos(angle) * r).roundToDouble(),
                      (cy + math.sin(angle) * r + q * 3).roundToDouble(),
                      colour);
                }
              }
            }
          case PipProp.lightning:
            // Round 70: a storm's bolt now and then (the flash is drawn
            // over everything, at the end).
            final phase = brain.sceneClock % _stormEvery;
            if (phase < _flashTime) {
              final cycle = (brain.sceneClock / _stormEvery).floor();
              var x = (_hash(cycle) % math.max(1, columns - 10) + 5).toDouble();
              for (var y = 0.0; y < groundTop * 0.6; y++) {
                dot(x, y, PipColours.lightning);
                if (y % 3 == 2) x += _hash(cycle + y.toInt()).isEven ? 1 : -1;
              }
            }
          default:
            // Round 70: the field's things are drawn on the ground, the
            // weather over everything.
            break;
        }
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

    // The ground: a row of grass with lighter tufts, dirt with specks.
    // Round 63: out on his adventure, it moves under him (and a pebble
    // now and then shows it).
    final run = brain.run;
    final shift = run?.shift.floor() ?? 0;
    // Round 67: a ski day's snow instead of grass; Round 70: or while it
    // snows. The grass in its season's colours.
    final skiSnow = brain.snowing;
    final snowy = skiSnow || (scene?.snowyGround ?? false);
    final season = scene?.season;
    final (grass, grassLight) = switch (season) {
      Season.autumn => (PipColours.grassAutumn, PipColours.grassAutumnLight),
      Season.winter => (PipColours.grassWinter, PipColours.frost),
      _ => (PipColours.grass, PipColours.grassLight),
    };
    // Round 72: skiing down, the room is the slope (below).
    final downhill = run?.downhill ?? false;
    // Pines along the back on a ski day.
    if (skiSnow && !downhill) {
      for (final at in const [0.12, 0.42, 0.7, 0.9]) {
        final px = ((columns * at - shift * 0.5) % (columns + 12)) - 6;
        sprite(PipSprites.pine, px.floorToDouble(), groundTop,
            colours: PipSprites.snowColours);
      }
    }

    /// [rows] at [scale] (Round 72: smaller further away), its bottom
    /// middle at [x], [bottom].
    void scaled(List<String> rows, double x, double bottom, double scale,
        Map<String, Color> colours) {
      canvas.save();
      final width = rows.first.length * scale;
      canvas.translate((x - width / 2) * pixel, bottom * pixel);
      canvas.scale(scale);
      for (var j = 0; j < rows.length; j++) {
        for (var i = 0; i < rows[j].length; i++) {
          final colour = colours[rows[j][i]];
          if (colour == null) continue;
          canvas.drawRect(
              Rect.fromLTWH(i * pixel, (j - rows.length) * pixel, pixel + 0.5,
                  pixel + 0.5),
              paint..color = colour);
        }
      }
      canvas.restore();
    }

    // Round 72 (Nikola: he should ski *down*): seen from below, the slope
    // runs up to a horizon with mountains; what he passes comes up from
    // the bottom of the screen and shrinks away to it, his tracks too.
    if (downhill) {
      final ski = run!;
      final top = (groundTop * PipRun.horizon).floorToDouble();
      final middle = columns / 2;
      double yAt(double behind) =>
          top + (groundTop - top) * PipRun.nearness(behind);
      double xAt(double x, double behind) =>
          middle + (x - middle) * PipRun.nearness(behind);
      // The mountains, peaked, snow on their tops, the side away from
      // the sun shaded.
      final big = groundTop > 40;
      final rise = big ? 16.0 : 10.0;
      for (var x = 0; x < columns; x++) {
        var high = 0.0;
        var shaded = false;
        for (var k = -1; k < columns ~/ 26 + 2; k++) {
          final peak = k * 26.0 + (_hash(k + 7) % 12);
          final tallest = rise * (0.55 + (_hash(k + 3) % 45) / 100);
          final h = tallest - (x - peak).abs() * 0.75;
          if (h > high) {
            high = h;
            shaded = x > peak;
          }
        }
        if (high <= 0) continue;
        final peakY = (top - high).floorToDouble();
        final cap = math.min(high, math.max(1.0, high - rise * 0.45));
        dot(x.toDouble(), peakY, PipColours.snow, 1, high - cap + 1);
        dot(
            x.toDouble(),
            peakY + high - cap + 1,
            shaded ? PipColours.mountainShade : PipColours.mountain,
            1,
            math.max(0, cap - 1));
      }
      // The slope: shaded far off, bright near.
      for (var y = top; y < height; y++) {
        final near = ((y - top) / (height - top)).clamp(0.0, 1.0);
        dot(0, y, Color.lerp(PipColours.snowShade, PipColours.snow, near)!,
            columns.toDouble(), 1);
      }
      // Specks of snow on it, going by.
      for (var i = 0; i < columns; i++) {
        final behind = (i * 29 + ski.drop) % (PipRun.farthest + 10) - 10.0;
        final x = (_hash(i) % (columns * 16 ~/ 10)) - columns * 0.3;
        dot(xAt(x, behind).floorToDouble(), yAt(behind).floorToDouble(),
            PipColours.snowShade);
      }
      // His tracks, back up the slope behind him.
      for (var behind = 1.0; behind < PipRun.farthest; behind += 2) {
        final at =
            ski.centre + PipRun.swayAt(ski.drop - behind) + PipBrain.width / 2;
        final y = yAt(behind).floorToDouble();
        if (y > groundTop - 1) continue; // under him
        dot(xAt(at - 4, behind).floorToDouble(), y, PipColours.snowShade);
        dot(xAt(at + 3, behind).floorToDouble(), y, PipColours.snowShade);
      }
      // A bump coming up under him.
      if (ski.bump case final behind?) {
        final f = PipRun.nearness(behind);
        final x = xAt(ski.centre + PipBrain.width / 2, behind);
        final y = yAt(behind);
        dot((x - 8 * f).floorToDouble(), (y - 2 * f).floorToDouble(),
            PipColours.snow, 16 * f, 2 * f);
        dot((x - 8 * f).floorToDouble(), y.floorToDouble(),
            PipColours.snowShade, 16 * f, 1);
      }
      // Trees and flags, the furthest first.
      final things = [...ski.slope]..sort((a, b) => b.at.compareTo(a.at) * -1);
      for (final s in things) {
        final behind = ski.drop - s.at;
        final f = PipRun.nearness(behind);
        final (art, size) = switch (s.kind) {
          SlopeThing.tree => (PipSprites.pine, 2.2),
          SlopeThing.redFlag => (PipSprites.flagRed, 1.4),
          SlopeThing.blueFlag => (PipSprites.flagBlue, 1.4),
        };
        scaled(art, xAt(s.x, behind), yAt(behind), f * size,
            PipSprites.snowColours);
      }
    }
    // Round 67: on the bus, a road moving under it, posts going by.
    final bus = brain.bus;
    final road = bus?.road.floor() ?? 0;
    if (bus != null) {
      for (var k = 0; k < columns ~/ 40 + 2; k++) {
        final px =
            ((k * 40 - road) % (columns + 40) + columns + 40) % (columns + 40) -
                20;
        dot(px.toDouble(), groundTop - 9, PipColours.pole, 1, 9);
        dot(px - 1.0, groundTop - 9, PipColours.flagRed, 3, 1);
      }
    }
    for (var x = 0; x < columns && !downhill; x++) {
      if (bus != null) {
        dot(x.toDouble(), groundTop, PipColours.road, 1,
            PipRoom.ground.toDouble());
        if ((x + road) % 12 < 6) {
          dot(x.toDouble(), groundTop + 2, PipColours.roadLine);
        }
        dot(x.toDouble(), groundTop - 1, snowy ? PipColours.snow : grass);
        continue;
      }
      final gx = x + shift;
      final h = (gx * 7919) % 13; // the same tufts every time
      dot(x.toDouble(), groundTop, snowy ? PipColours.snow : grass);
      if (h < 3) {
        dot(x.toDouble(), groundTop - 1, snowy ? PipColours.snow : grassLight);
      }
      // Round 70: autumn's fallen leaves on the grass.
      if (!snowy && season == Season.autumn && (gx * 131) % 17 == 0) {
        dot(x.toDouble(), groundTop,
            gx.isEven ? PipColours.leafAutumnDark : PipColours.leafAutumnLight);
      }
      if (run != null && !snowy && gx % 47 == 0) {
        dot(x.toDouble(), groundTop - 1, PipColours.batteryCase, 2, 1);
      }
      for (var y = 1; y < PipRoom.ground; y++) {
        final speck = (gx * 31 + y * 17) % 11 == 0;
        dot(
            x.toDouble(),
            groundTop + y,
            snowy
                ? (speck ? PipColours.snowDark : PipColours.snowShade)
                : (speck ? PipColours.dirtDark : PipColours.dirt));
      }
    }

    // Round 70: his field's things through the year, behind him: a tree
    // or two swaying (scrolling by as he runs, or rides), Christmas's
    // pine, Halloween's lanterns, Easter's eggs.
    final props = scene?.props ?? const <PipProp>{};
    final home = groundTop > 40;
    final passing = fieldPassing(brain);
    double along(double at, double width, double by) {
      final wide = columns + width * 2;
      return ((columns * at - by) % wide + wide) % wide - width;
    }

    if (!skiSnow) {
      final windy = scene?.weather?.wet ?? false;
      if (props.contains(PipProp.trees)) {
        // Round 74: each spot's tree its own look (an oak, a birch, a pine).
        final shade = season ?? Season.summer;
        // Round 72: in their spots for this time the app's open, in full
        // view; beside the road (not on it) while he rides the bus.
        final base = bus != null ? groundTop - 1 : groundTop;
        for (final (i, (at: at, kind: kind)) in _treeSpots.indexed) {
          final (art, colours, crownRows) = PipSprites.treeOf(kind, shade);
          final bare = shade == Season.winter && kind != PipTreeKind.pine;
          final wide = art.first.length.toDouble();
          final room = math.max(0.0, columns - wide - 4);
          // (along() takes the right edge's share: the whole tree in view.)
          final left = along((2 + room * at + wide) / columns, wide, passing)
              .floorToDouble();
          final top = base - art.length;
          for (var y = 0; y < art.length; y++) {
            // The crown sways, most at the top (a pine's stiffer).
            final crown = y < crownRows;
            final reach = (crown ? 1 - y / crownRows : 0.0) *
                (kind == PipTreeKind.pine ? 0.5 : 1);
            final sway =
                (math.sin(brain.sceneClock * (windy ? 2.6 : 1.3) + i * 1.7) *
                        reach *
                        (windy ? 2.2 : 1.2))
                    .roundToDouble();
            for (var x = 0; x < art[y].length; x++) {
              var colour = colours[art[y][x]];
              if (colour == null) continue;
              // Snow on a bare tree's branches and a pine's tiers while it
              // snows.
              if (snowy &&
                  (bare || kind == PipTreeKind.pine) &&
                  y < crownRows &&
                  (x + y).isEven) {
                colour = PipColours.snow;
              }
              dot(left + x + sway, top + y, colour);
            }
          }
        }
      }
      if (props.contains(PipProp.festiveTree)) {
        final art = PipSprites.festiveTree;
        final left = along(0.74, 14, passing).floorToDouble();
        final blink = (brain.sceneClock * 1.5).floor();
        for (var y = 0; y < art.length; y++) {
          for (var x = 0; x < art[y].length; x++) {
            final c = art[y][x];
            final colour = switch (c) {
              'G' =>
                snowy && (x + y) % 3 == 0 ? PipColours.snow : PipColours.pine,
              'g' => PipColours.pineDark,
              't' => PipColours.woodDark,
              'S' => PipColours.starGold,
              'a' || 'b' || 'c' || 'd' => PipSprites.festiveLights[
                  (c.codeUnitAt(0) - 97 + blink) %
                      PipSprites.festiveLights.length],
              _ => null,
            };
            if (colour != null) {
              dot(left + x, groundTop - art.length + y, colour);
            }
          }
        }
      }
      if (props.contains(PipProp.badnjak)) {
        // Round 72: Christmas: the badnjak, a candle by it (its flame
        // flickering), straw scattered on the grass.
        final left = along(0.74, 20, passing).floorToDouble();
        sprite(PipSprites.badnjak, left, groundTop + 1,
            colours: PipSprites.badnjakColours);
        final flicker = (brain.sceneClock * 6).floor() % 3;
        sprite(PipSprites.candle, left + 17, groundTop + 1, colours: {
          'f': flicker == 0 ? PipColours.pumpkinGlow : PipColours.leafAutumn,
          'F': flicker == 2 ? PipColours.lightRed : PipColours.starGold,
          'k': PipColours.barkDark,
          'w': PipColours.candle,
          'W': PipColours.candleShade,
        });
        for (final at in home ? const [0.18, 0.4, 0.58] : const [0.2, 0.5]) {
          sprite(PipSprites.straw, along(at, 7, passing).floorToDouble(),
              groundTop + 1,
              colours: PipSprites.badnjakColours);
        }
      }
      if (props.contains(PipProp.pumpkins)) {
        final lit = scene?.part == DayPart.night || scene?.part == DayPart.dusk;
        final flicker = (brain.sceneClock * 7).floor() % 5 == 0;
        for (final at in home ? const [0.3, 0.58, 0.88] : const [0.32, 0.9]) {
          final left = along(at, 8, shift.toDouble()).floorToDouble();
          sprite(PipSprites.pumpkin, left, groundTop, colours: {
            'p': PipColours.pumpkin,
            'P': PipColours.pumpkinDark,
            's': PipColours.pumpkinStem,
            'y': lit
                ? (flicker
                    ? PipColours.leafAutumnLight
                    : PipColours.pumpkinGlow)
                : PipColours.pumpkinDark,
          });
        }
      }
      if (props.contains(PipProp.eggs)) {
        const colours = [
          (PipColours.eggPink, PipColours.eggBlue),
          (PipColours.eggYellow, PipColours.eggRed),
          (PipColours.eggBlue, PipColours.eggYellow),
          (PipColours.eggRed, PipColours.screen),
        ];
        for (final (i, at) in const [0.2, 0.45, 0.63, 0.86].indexed) {
          final (e, stripe) = colours[i];
          sprite(PipSprites.easterEgg,
              along(at, 4, shift.toDouble()).floorToDouble(), groundTop + 1,
              colours: {'e': e, 'E': stripe});
        }
      }
    }

    /// His sword, its grip's middle at [hand] (screen), turned by [angle]
    /// (0: pointing up) and scaled by [size].
    void blade(Offset hand, double angle, double size) {
      canvas.save();
      canvas.translate(hand.dx, hand.dy);
      canvas.rotate(angle);
      canvas.scale(size);
      final art = PipSprites.sword;
      for (var y = 0; y < art.length; y++) {
        for (var x = 0; x < art[y].length; x++) {
          final colour = PipSprites.fieldColours[art[y][x]];
          if (colour == null) continue;
          // The middle of the grip in the hand.
          canvas.drawRect(
            Rect.fromLTWH((x - art[y].length / 2) * pixel,
                (y - PipSprites.swordGrip - 0.5) * pixel, pixel, pixel),
            paint..color = colour,
          );
        }
      }
      canvas.restore();
    }

    /// His ski trip's bus, its door open as he gets on or off.
    void drawBus(PipBus bus) {
      final left = bus.busX.floorToDouble();
      final top = groundTop - PipBus.height;
      sprite(PipSprites.bus, left, groundTop, colours: PipSprites.busColours);
      // Round 72: his window's glass over him (he's behind it).
      const w = PipBus.window;
      dot(
          left + w.left,
          top + w.top,
          PipColours.busGlass.withValues(alpha: 0.28),
          (w.right - w.left + 1).toDouble(),
          (w.bottom - w.top + 1).toDouble());
      dot(left + w.left + 2, top + w.top + 1,
          PipColours.cloudLight.withValues(alpha: 0.5), 1, 3);
      if (bus.doorOpen) {
        dot(left + PipBus.doorX + 1, top + 4, PipColours.busInside,
            PipBus.doorWidth - 2.0, 27);
      }
    }

    /// Round 72: inside the bus behind his window: the seats' row and a
    /// seat back, drawn before him.
    void busInside(PipBus bus) {
      final left = bus.busX.floorToDouble();
      final top = groundTop - PipBus.height;
      const w = PipBus.window;
      dot(left + w.left, top + w.top, PipColours.busInside,
          (w.right - w.left + 1).toDouble(), (w.bottom - w.top + 1).toDouble());
      dot(left + w.right - 4, top + w.top + 6, PipColours.busSeat, 4,
          (w.bottom - w.top - 5).toDouble());
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
    // Round 67: his ski gear in its snowbank.
    if (brain.gearInBank) {
      sprite(PipSprites.gearBank, PipRun.gearX - 2, groundTop,
          colours: PipSprites.snowColours);
    }
    // Round 64: his day out's tavern, its table and his bench (Round 67:
    // a ski day's, a hut with snow on its roof).
    if (run != null) {
      if (run.tavern case final tx?) {
        sprite(PipSprites.tavern, tx.floorToDouble(), groundTop,
            colours:
                run.skiing ? PipSprites.hutColours : PipSprites.tavernColours);
        sprite(PipSprites.table, (tx + PipRun.tableLeft).floorToDouble(),
            groundTop,
            colours: PipSprites.tavernColours);
        sprite(PipSprites.bench, (tx + PipRun.seatOffset + 4).floorToDouble(),
            groundTop,
            colours: PipSprites.tavernColours);
      }
      // A ski come off in a fall, sliding away, then lying there.
      if (run.skiAt case final sx?) {
        dot(sx.floorToDouble(), groundTop - 1, PipColours.ski, 12, 1);
        dot(sx.floorToDouble() + 11, groundTop - 2, PipColours.ski);
      }
      // His sword, knocked out of his hand: flying, then lying there.
      if (run.lyingSword case (final sx, final up, final angle)) {
        blade(Offset(sx * pixel, (groundTop - up) * pixel), angle, 1);
      }
    }
    // A bug crawling in, its legs stepping; mirrored going right. Round
    // 73: out, a beetle, a spider or the boss too, flashing as it's
    // struck, the strikes it can still take over it.
    if (brain.bug case (final bx, final legsUp, final toRight)) {
      final fight =
          brain.activity == PipActivity.adventuring ? brain.run : null;
      final foe = fight?.foe ?? PipFoe.bug;
      final art = PipSprites.foeArt(foe, legsUp);
      sprite(art, bx, groundTop,
          colours: fight?.foeFlash ?? false
              ? PipSprites.foeFlashColours
              : PipSprites.foeColours,
          mirror: toRight);
      if (fight != null && foe.hits > 1) {
        final left = fight.foeHitsLeft;
        final from = bx + (art.first.length - (left * 2 - 1)) / 2;
        for (var i = 0; i < left; i++) {
          dot((from + i * 2).floorToDouble(), groundTop - art.length - 3,
              PipColours.bugEye);
        }
      }
    }
    // A ball, rolling (its stripe turning) or bouncing off.
    if (brain.ball case (final bx, final up, final turn)) {
      sprite(PipSprites.ballFrames[turn], bx, groundTop - up,
          colours: PipSprites.fieldColours);
    }

    // Round 67: the bus, behind him while he's outside it; Round 72: in
    // it, the inside behind him first.
    if (bus != null && bus.busShown && !bus.inside) drawBus(bus);
    if (bus != null && bus.busShown && bus.inside) busInside(bus);

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
      final top = PipSprites.hatBottom -
          art.length +
          1 +
          (PipSprites.hatDrop[hat] ?? 0);
      for (var y = 0; y < art.length; y++) {
        for (var x = 0; x < art[y].length; x++) {
          final colour = PipSprites.hatColours[art[y][x]];
          if (colour != null) {
            own(PipSprites.hatLeftOf(art) + x, top + y, colour);
          }
        }
      }
    }
    canvas.restore();
    // Round 67: in his seat: the bus over him, him in its window.
    if (bus != null && bus.busShown && bus.inside) drawBus(bus);
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
    // Round 58: the station's drone, flying to him while he's off, its
    // beam on him as it charges him.
    if (brain.drone case (final dx, final dy, final beaming)) {
      if (beaming) {
        final middle = dx + PipBrain.droneWidth / 2;
        final top = groundTop - dy;
        final reach = dy - PipBrain.beamTo;
        for (var i = 0.0; i < reach; i++) {
          // Flickering, fading down towards him.
          final a = (brain.droneSpin ? 0.95 : 0.7) * (1 - i / (reach + 4));
          dot(middle - 1, top + i, PipColours.stationBolt.withValues(alpha: a),
              2, 1);
        }
      }
      sprite(PipSprites.drone[brain.droneSpin ? 0 : 1], dx, groundTop - dy,
          colours: PipSprites.stationColours);
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
    // A bug struck: a poof (Round 73: bigger for a bigger foe).
    if (brain.poof case (final px, final t)) {
      final size = brain.activity == PipActivity.adventuring
          ? brain.run?.poofSize ?? 1
          : 1.0;
      final out = (1 + 4 * t) * math.sqrt(size);
      final rise = (size - 1) * 1.5;
      for (final (ox, oy) in const [
        (-1, -1),
        (1, -1),
        (-1, 1),
        (1, 1),
        (0, -1),
        (-1, 0),
        (1, 0),
      ]) {
        dot(
            (px + ox * out).floorToDouble(),
            (groundTop - 2 - rise + oy * out * 0.7).floorToDouble(),
            PipColours.puff);
      }
    }
    // Round 73: the XP he gained, rising over it and fading.
    for (final (xp, px, f)
        in brain.run?.xpRising ?? const <(int, double, double)>[]) {
      final art = PipSprites.tinyText('+$xp XP');
      final left = (px - art.first.length / 2).floorToDouble();
      final top = groundTop - 16 - (8 * f).floorToDouble();
      final fade = f < 0.6 ? 1.0 : 1 - (f - 0.6) / 0.4;
      sprite(art, left + 1, top + 1,
          alpha: fade, colours: const {'x': PipColours.levelUpShade});
      sprite(art, left, top,
          alpha: fade, colours: const {'x': PipColours.levelUp});
    }
    // His sword, in a floating hand: raised, swung, popping in and away.
    if (brain.sword case (final hx, final hy, final angle, final size)
        when size > 0.05) {
      blade(Offset(hx * pixel, (groundTop - hy) * pixel), angle, size);
      sprite(PipSprites.mitt, hx - 1, groundTop - hy + 2);
    }
    // Round 67: his skis under his feet, his poles in his hands.
    if (run != null && run.skisOn) {
      final feet = bottom.floorToDouble();
      final long = run.oneSki ? 12.0 : PipBrain.width + 6.0;
      dot(brain.x - 3, feet, PipColours.ski, long, 1);
      if (!run.oneSki) {
        dot(brain.x + PipBrain.width + 3, feet - 1, PipColours.ski);
      }
      for (final side in const [-1.0, 1.0]) {
        final hx = side < 0 ? brain.x - 1 : brain.x + PipBrain.width;
        _line(dot, hx, feet - 8, hx - side * -2, feet, PipColours.pole);
        dot(hx, feet - 8, PipColours.screen);
      }
    }
    // A puff of snow where he fell.
    if (run?.snowPuff case final t?) {
      for (var i = 0; i < 6; i++) {
        final side = i.isEven ? 1 : -1;
        final out = 4 + (2 + i) * t * 3;
        final up = 5 * math.sin(math.pi * t) * (1 - i * 0.12);
        dot((centre + side * out).floorToDouble(),
            (groundTop - 1 - up).floorToDouble(), PipColours.flake);
      }
    }
    // Round 67: on a ski break, a mug of hot chocolate instead of a plate
    // (Round 74: lifted to his mouth for a sip).
    if (run != null && run.skiing) {
      if (run.plateAt case (final px0, final py0, final left)) {
        final (px, py) = switch (run.hand) {
          (final hx, final hy, _, _) => (hx, hy - 1),
          null => (px0, py0),
        };
        final mx = (px - 3).floorToDouble();
        final my = (groundTop - py).floorToDouble();
        sprite(PipSprites.mug, mx, my, colours: PipSprites.snowColours);
        final level = (3 * left).ceil();
        if (level > 0) {
          dot(mx + 1, my - 1 - level, PipColours.cocoa, 3, level.toDouble());
        }
        if (left > 0) {
          for (var i = 0; i < 2; i++) {
            final rise = ((run.clock * 3 + i * 0.5) % 1);
            dot(
                mx + 1 + i * 2 + (rise * 2).floorToDouble() % 2,
                my - 6 - (rise * 4).floorToDouble(),
                PipColours.steam.withValues(alpha: 1 - rise));
          }
        }
      }
    } else if (run?.plateAt case (final px, final py, final left)) {
      final plateLeft = (px - PipBrain.plateWidth / 2).floorToDouble();
      final bottom = (groundTop - py).floorToDouble();
      sprite(PipSprites.plate, plateLeft, bottom,
          colours: PipSprites.fieldColours);
      sprite(PipSprites.meal((left * 3).ceil()), plateLeft,
          bottom - PipSprites.plate.length,
          colours: PipSprites.fieldColours);
    }
    // Round 74: his hand taking a bite to his mouth (or holding his mug).
    if (run?.hand case (final hx, final hy, final size, final carrying)
        when size > 0.05) {
      final w = PipSprites.mitt[0].length * size;
      final h = PipSprites.mitt.length * size;
      final cx = hx + 1, cy = groundTop - hy - 1.5;
      for (var y = 0; y < PipSprites.mitt.length; y++) {
        for (var x = 0; x < PipSprites.mitt[y].length; x++) {
          dot(cx - w / 2 + x * size, cy - h / 2 + y * size,
              PipSprites.colours[PipSprites.mitt[y][x]]!, size, size);
        }
      }
      if (carrying && !run!.skiing) {
        // The bite, held up.
        dot(cx.floorToDouble() - 1, (cy - h / 2 - 1).floorToDouble(),
            PipColours.meal, 2, 1);
        dot(cx.floorToDouble(), (cy - h / 2 - 2).floorToDouble(),
            PipColours.mealDark);
      }
    }
    // Round 63: LEVEL UP over him, rising and fading.
    if (brain.levelFlash case final f?) {
      final art = PipSprites.levelUp;
      final left = (centre - art.first.length / 2).floorToDouble();
      final top = groundTop - PipBrain.height - 8 - (6 * f).floorToDouble();
      final fade = f < 0.7 ? 1.0 : (1 - (f - 0.7) / 0.3);
      final on = (f * 12).floor().isEven || f > 0.3;
      if (on) {
        sprite(art, left + 1, top + 1,
            alpha: fade, colours: const {'x': PipColours.levelUpShade});
        sprite(art, left, top,
            alpha: fade, colours: const {'x': PipColours.levelUp});
      }
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
      sprite(
          words, crossWordsLeft(brain, centre), groundTop - PipBrain.height + 1,
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
    // Round 67: snowing on a ski day, drifting down (rising past him as
    // he skis down).
    if (brain.snowing) {
      final t = brain.snowClock;
      final rise = run?.downhill == true ? run!.drop * 0.5 : 0.0;
      final rows = height.toDouble();
      for (var i = 0; i < columns ~/ 3; i++) {
        final speedY = 5.0 + (i % 3) * 2;
        final fx = (i * 37 + 3 * math.sin(t * 0.8 + i)) % columns;
        final fy = ((i * 53 + t * speedY - rise) % rows + rows) % rows;
        dot(fx.floorToDouble(), fy.floorToDouble(),
            i % 4 == 0 ? PipColours.snowShade : PipColours.flake);
      }
    }
    // Round 70: the weather, over everything: snow falling (a ski day's
    // is above), rain, leaves or petals drifting down, fog, a storm's
    // flash.
    final t = brain.sceneClock;
    final tall = height.toDouble();
    final strength = (scene?.strength ?? 1).clamp(1, 3);
    if (props.contains(PipProp.snowfall) && !skiSnow) {
      for (var i = 0; i < columns * strength ~/ 6; i++) {
        final speedY = 5.0 + (i % 3) * 2;
        final fx = (i * 37 + 3 * math.sin(t * 0.8 + i)) % columns;
        final fy = ((i * 53 + t * speedY) % tall + tall) % tall;
        dot(fx.floorToDouble(), fy.floorToDouble(),
            i % 4 == 0 ? PipColours.snowShade : PipColours.flake);
      }
    }
    if (props.contains(PipProp.rain)) {
      // Round 72 (Nikola didn't like the dashes): long thin streaks, slanted
      // with the wind, in two layers (far ones fainter and slower), and
      // little splashes where they hit the ground.
      final drizzle = scene?.weather == WeatherKind.drizzle;
      final count = columns * (drizzle ? 1 : strength + 1) ~/ 4;
      final length = drizzle ? 2 : 4 + strength;
      for (var i = 0; i < count; i++) {
        final far = i % 3 == 0;
        final speed = (far ? 70.0 : 110.0) + (i % 5) * 6;
        final span = tall + length + 4;
        final head = (i * 71 + t * speed) % span - length;
        final x0 = (i * 41 + head * 0.35) % (columns + 10) - 5;
        final colour = PipColours.raindrop.withValues(alpha: far ? 0.35 : 0.65);
        for (var k = 0; k < length; k++) {
          final y = head - k;
          if (y < 0 || y >= groundTop) continue;
          dot((x0 - k * 0.35).floorToDouble(), y.floorToDouble(), colour);
        }
        // Landed: a splash for a moment.
        if (!far && head >= groundTop && head < groundTop + 3) {
          final sx = (x0 - (head - groundTop) * 0.35).floorToDouble();
          final splash = PipColours.raindrop.withValues(alpha: 0.7);
          dot(sx - 1, groundTop - 1, splash);
          dot(sx + 1, groundTop - 1, splash);
          dot(sx - 2, groundTop - 2, splash.withValues(alpha: 0.4));
          dot(sx + 2, groundTop - 2, splash.withValues(alpha: 0.4));
        }
      }
    }
    if (props.contains(PipProp.leaves) || props.contains(PipProp.petals)) {
      final petals = props.contains(PipProp.petals);
      final colours = petals
          ? const [PipColours.blossom, PipColours.blossomLight]
          : const [
              PipColours.leafAutumn,
              PipColours.leafAutumnDark,
              PipColours.leafAutumnLight,
            ];
      for (var i = 0; i < (home ? 7 : 4); i++) {
        final fy = ((i * 29 + t * (4 + i % 3)) % tall);
        final fx = ((i * 47 + t * 3 + 4 * math.sin(t * 1.2 + i * 2)) % columns +
                columns) %
            columns;
        dot(fx.floorToDouble(), fy.floorToDouble(),
            colours[i % colours.length]);
      }
    }
    if (props.contains(PipProp.fog)) {
      final fog = PipColours.fog.withValues(alpha: 0.28);
      for (var band = 0; band < (home ? 4 : 2); band++) {
        final top = (groundTop * (0.3 + band * 0.18)).floorToDouble();
        final drift = (t * (3 + band) + band * 40) % columns;
        dot(0, top, fog, columns.toDouble(), home ? 7 : 5);
        dot(drift - columns / 2, top + 2, fog, columns / 2, 3);
      }
    }
    if (props.contains(PipProp.lightning) && t % _stormEvery < _flashTime) {
      canvas.drawRect(Offset.zero & size,
          paint..color = PipColours.lightning.withValues(alpha: 0.3));
    }
    // The egg's bottom half in front of him, as he jumps out of it.
    if (hatching) {
      sprite(PipSprites.eggBottom, eggLeft, groundTop, alpha: shell);
    }
  }

  /// Round 70: a storm's bolt and flash, every [_stormEvery] seconds for
  /// [_flashTime].
  static const _stormEvery = 6.5;
  static const _flashTime = 0.18;

  @override
  bool shouldRepaint(_RoomPainter old) => true;
}

/// How far his field's things (the trees) have gone by: half the
/// ground's shift (they're further off), and the bus's road. Round 74:
/// out, by his time running (his life's), so the menu's room and Pip
/// Home's agree (each has its own run).
double fieldPassing(PipBrain brain) {
  final running = brain.outRun;
  if (running != null && brain.activity == PipActivity.adventuring) {
    return running * PipRun.runSpeed * 0.5;
  }
  final shift = brain.run?.shift.floor() ?? 0;
  final road = brain.bus?.road.floor() ?? 0;
  return shift * 0.5 + road * 0.6;
}

/// Round 72: where his field's trees stand for this time the app's open
/// (Round 74: and how each looks).
List<PipTreeSpot> _treeSpots = treeSpots(math.Random());

/// Sets the trees' spots and looks (tests and pictures).
@visibleForTesting
set debugTreeSpots(List<PipTreeSpot> spots) => _treeSpots = spots;

/// A tree's spot (a share of the room's width) and look.
typedef PipTreeSpot = ({double at, PipTreeKind kind});

/// Round 72: where his field's two trees stand, picked by [random]: one
/// on the left part, one well to the right, so it isn't always the same
/// view. Round 74: each an oak, a birch or a pine.
List<PipTreeSpot> treeSpots(math.Random random) {
  PipTreeKind kind() =>
      PipTreeKind.values[random.nextInt(PipTreeKind.values.length)];
  return [
    (at: random.nextDouble() * 0.3, kind: kind()),
    (at: 0.62 + random.nextDouble() * 0.38, kind: kind()),
  ];
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

/// Where his cross words start (their left column) with his frame's
/// middle at [centre]. Round 53: low, just over his head beside his
/// antenna, away from the fist. Round 58: in a hat (centred, over his
/// antenna), further out, clear of it.
double crossWordsLeft(PipBrain brain, double centre) {
  final hat = brain.hatBeside ? null : PipSprites.hats[brain.hat];
  // Clear of the hat's brim (Round 72: the beanie's as wide as his head).
  final out =
      hat == null ? 0 : math.max(2, 7 - PipSprites.hatLeftOf(hat)).toDouble();
  return brain.facingRight ? centre - 10 - out : centre + 3 + out;
}
