import 'dart:math' as math;

import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_weather.dart';

/// What stands on his ski slope (Round 67).
enum SlopeThing { tree, redFlag, blueFlag }

/// What he fights on his day out (Round 73): bugs, and now and then
/// bigger ones that take more than one strike; once a day out, if he's
/// watched, a boss.
enum PipFoe {
  bug(hits: 1, width: 8, crawl: 6),
  beetle(hits: 2, width: 12, crawl: 5),
  spider(hits: 3, width: 14, crawl: 7),
  boss(hits: 6, width: 24, crawl: 3.5),

  /// Round 75: in the snow, a snowman coming at him (two strikes).
  snowman(hits: 2, width: 12, crawl: 4);

  /// Strikes it takes, its width, and how fast it crawls at him.
  final int hits;
  final int width;
  final double crawl;

  const PipFoe({required this.hits, required this.width, required this.crawl});
}

/// Where he is in his day out (Round 63).
enum RunPhase {
  /// Just registered: his sword held up high, a fanfare.
  cheer,

  /// Walking to the middle of his room.
  toCentre,

  /// Drawing his sword.
  drawing,

  /// Running right (the ground moving under him), striking bugs.
  running,

  /// A bug got him: knocked back, his sword flying off.
  knocked,

  /// On the ground a moment after.
  down,

  /// Going back for his sword...
  toSword,

  /// ...picking it up...
  pickUp,

  /// ...and back to the middle.
  back,

  /// Round 64: a tavern coming up; he runs till it's beside him.
  arriving,

  /// Putting the sword away, walking to his seat.
  toSeat,

  /// Sitting at the table: a plate flies out of the window, he eats.
  sitting,

  /// Up from the table.
  standUp,

  /// 18:00: slowing to a stop, the sword away.
  ending,

  // Round 67: skiing (a ski day's look for his day out).

  /// Walking to his gear in the snowbank...
  toGear,

  /// ...taking it (skis on, poles in hand); at the end, putting it back.
  takeGear,
  putGear,

  /// A fall: tumbling forward, a ski coming off and sliding away...
  skiFall,

  /// ...walking to it...
  toSki,

  /// ...and stepping back in.
  skiOn,

  /// Round 75: a storm: slowing to a stop, the sword away...
  toShelter,

  /// ...in his tent by the path till it's over (it comes down after).
  sheltering,

  /// Over: he's back to his usual self.
  done,
}

/// His day out as it's drawn (Round 63): Pip in the middle of his room,
/// running, while the ground and what's on it scroll by. Measured in the
/// room's pixels; "world" places move with the ground ([shift]), so a
/// thing at world x is drawn at x − [shift].
class PipRun {
  final math.Random random;

  PipRun(this.random,
      {required this.x, required this.roomWidth, this.skiing = false});

  /// Round 67: a ski day: he skis down instead of running right; no bugs,
  /// no sword; poles and skis from his gear in the snowbank ([gearX]).
  final bool skiing;

  /// Where his gear stands in the snowbank (its left edge).
  static const gearX = 3.0;

  /// His gear on him (skis on his feet, poles in his hands).
  bool get geared => skiing && _geared;
  bool _geared = false;

  int roomWidth;
  RunPhase phase = RunPhase.running;

  /// Seconds into [phase], and since the start (his steps).
  double t = 0;
  double clock = 0;

  /// How far the ground has moved, and how fast it's moving now.
  double shift = 0;
  double speed = 0;

  /// His left edge on the screen, and which way he faces.
  double x;
  bool facingRight = true;

  /// Moments to feel, taken by his brain.
  final buzzes = <PipBuzz>[];

  static const runSpeed = 20.0;
  static const walkSpeed = PipBrain.speed * 1.3;
  static const cheerTime = 3.0;
  static const drawTime = 0.35;
  static const swingTime = 0.3;
  static const poofTime = 0.35;
  static const knockTime = 0.7;
  static const downTime = 0.5;
  static const pickTime = 0.45;
  static const sheatheTime = 0.4;
  static const plateFlight = 0.6;
  static const standUpTime = 0.4;
  static const endTime = 0.9;

  /// How often bugs come (seconds, from the last; how fast each crawls
  /// is its [PipFoe.crawl]), and the chance one gets him first.
  static const bugFrom = 2.5;
  static const bugSpread = 4.0;
  static const hitChance = 0.2;

  /// The middle of the room, where he runs.
  double get centre => math.max(0, roomWidth - PipBrain.width) / 2;

  // Wanted by his life: his break, and the end of the day out.
  bool _wantBreak = false;
  bool _wantEnd = false;

  /// How far through his break (0 to 1): the meal eaten as it goes.
  double breakDone = 0;

  /// His life says: on his break or not (and how far), or over.
  /// Round 75: the weather out (his brain says): a storm (he shelters
  /// in his tent), snow (snowmen among the bugs), his pace (slower in
  /// fog).
  bool storm = false;
  bool snowFoes = false;
  double pace = 1;

  /// His tent by the path in a storm (screen place; the ground's still).
  PipTent? tent;

  /// Hidden in his tent.
  bool get inTent =>
      (tent?.hides ?? false) &&
      (phase == RunPhase.sheltering || phase == RunPhase.toShelter);

  static const shelterSlow = 0.6;

  /// The chance a foe in the snow is a snowman.
  static const snowmanChance = 0.3;

  void want({required bool onBreak, double done = 0, bool end = false}) {
    _wantBreak = onBreak;
    breakDone = done;
    _wantEnd = end;
  }

  /// Starts his day out: [cheer] (just registered), else seen ([animate]:
  /// he walks to the middle and draws his sword) or simply running.
  void start({bool cheer = false, required bool animate}) {
    if (cheer) {
      _to(RunPhase.cheer);
    } else if (animate) {
      _to(skiing ? RunPhase.toGear : RunPhase.toCentre);
    } else {
      x = centre;
      _geared = true;
      _go();
      _to(RunPhase.running);
    }
  }

  /// Off he goes: running right, or (skiing) down the slope.
  void _go() {
    if (skiing) {
      // Round 72: the slope already dotted with what he's passed.
      if (slope.isEmpty && tavernAt == null) {
        for (var behind = 0.0; behind < farthest; behind += 18) {
          _placeThing(drop - behind - random.nextDouble() * 12);
        }
      }
      // The slope moves past him; the ground doesn't (the hut, after his
      // break, slides away).
      speed = tavernAt == null ? 0 : runSpeed;
      _dropSpeed = skiSpeed;
    } else {
      speed = runSpeed;
    }
  }

  // Round 67: skiing down. Round 72 (he should go *down*): the
  // room becomes the slope, seen from below; what he passes comes up
  // from the bottom of the screen and shrinks away to the horizon.

  /// How far down the slope he's gone, and how fast now.
  double drop = 0;
  double _dropSpeed = 0;
  static const skiSpeed = 30.0;

  /// Downhill: the slope view (not at the hut, nor walking to his gear).
  bool get downhill =>
      skiing &&
      tavernAt == null &&
      const {
        RunPhase.running,
        RunPhase.skiFall,
        RunPhase.toSki,
        RunPhase.skiOn,
        RunPhase.back,
        RunPhase.ending,
      }.contains(phase);

  /// The slope's depth: a thing [behind] him (in [drop]'s units; below
  /// him, nearer, less than 0) is drawn at this share of its size and
  /// distance from the middle; 1 at his feet, shrinking to the horizon.
  static const depth = 24.0;
  static double nearness(double behind) =>
      behind <= -depth + 1 ? depth : depth / (depth + behind);

  /// Gone into the horizon past this far behind him.
  static const farthest = 180.0;

  /// Where the slope meets the sky, as a share of the sky's height.
  static const horizon = 0.42;

  /// His slalom: how far to the side of the middle he is at [at] along
  /// the slope.
  static double swayAt(double at) => 5 * math.sin(at / 16);

  /// Trees and flags on the slope: their x on the screen at his feet's
  /// depth, where on the slope ([drop] − at behind him) and which.
  final slope = <({double x, double at, SlopeThing kind})>[];
  double _nextThing = 0.5;

  /// A bump coming up under him (where on the slope), and his hop over it.
  double? _bumpAt;
  double _nextBump = 6;
  double _hop = -1;
  static const hopTime = 0.45;

  /// The next fall (seconds), and the ski that came off (on the screen).
  double _nextFall = fallFrom;
  static const fallFrom = 40.0;
  static const fallSpread = 50.0;
  static const fallTime = 0.8;
  static const skiOnTime = 0.4;
  static const gearTime = 0.5;
  double? skiAt;
  double _skiFrom = 0;

  /// Seen first while on his break: at the table, eating.
  void seated() {
    _geared = true;
    tavernAt = shift + _seatX(centre) - seatOffset;
    x = _seatX(centre);
    facingRight = false;
    speed = 0;
    plate = 1;
    _sheathed = true;
    _to(RunPhase.sitting);
  }

  void _to(RunPhase next) {
    phase = next;
    t = 0;
  }

  // A bug: its left edge (world), whether it gets him, running off after.
  double? bugAt;
  bool _hitter = false;
  bool _fleeing = false;
  double _nextBug = bugFrom;
  double _swing = -1;

  /// Round 73: what's coming ([PipFoe]), how many strikes it's taken,
  /// and its stagger back after one that didn't finish it (seconds in;
  /// -1: none).
  PipFoe foe = PipFoe.bug;
  int _struck = 0;
  double _recoil = -1;
  static const recoilTime = 0.3;
  static const recoilSpeed = 40.0;
  static const fleeSpeed = 30.0;

  /// The odds of a beetle (two strikes) or a spider (three) instead of a
  /// bug, and of the boss (six) while one may come ([bossDue]).
  static const beetleChance = 0.22;
  static const spiderChance = 0.08;
  static const bossChance = 0.04;

  /// A boss may come (his life says: none beaten today, and he's
  /// watched); once one has, not again this run.
  bool bossDue = false;
  bool _bossCame = false;

  /// Bugs come by themselves (a boss preview's fight: only its own).
  bool spawns = true;

  /// What he's struck down, taken by his brain (his life counts them).
  final defeats = <PipFoe>[];

  // A struck bug's poof: its middle (world), how far, and how big.
  double? _poofAt;
  double _poofT = 0;
  double _poofSize = 1;

  /// Round 73: XP gained, rising over where a foe was struck down: how
  /// much, its middle on the screen (it stays there), seconds in.
  final xpPops = <(int, double, double)>[];
  static const xpPopTime = 1.2;

  /// Shows [xp] gained over the last foe struck down.
  void popXp(int xp) {
    final at = _lastDown;
    if (at != null) xpPops.add((xp, at - shift, 0));
  }

  double? _lastDown;

  // His sword flying off and lying there: from and to (world).
  double _swordFrom = 0;
  double? swordAt;
  bool _sheathed = false;

  /// The tavern's left edge (world; Round 64), and the plate's flight to
  /// the table (0 to 1; null: not yet).
  double? tavernAt;
  double? plate;

  /// The tavern's size, and where in it: the window's middle, the table,
  /// and his seat (his left edge, from the tavern's left); his bench
  /// (Round 83: centred under him).
  static const tavernWidth = 54;
  static const windowMiddle = 22;
  static const tableLeft = 33;
  static const tableWidth = 10;
  static const tableHeight = 6;
  static const seatOffset = 42;
  static const benchLeft = seatOffset + (PipBrain.width - 12) / 2;

  double _seatX(double near) => near + 8;

  /// A bug coming now (a preview's, tests): [hits] him or not. Round 72:
  /// it crawls in from the room's edge, as any does (it was put just
  /// ahead of him, and seemed to teleport); not while one is coming.
  bool bugComing({required bool hits, PipFoe foe = PipFoe.bug}) {
    if (bugAt != null) return false;
    _come(foe, hits: hits);
    return true;
  }

  /// [kind] crawls in from the room's edge; [hits] him first or not (a
  /// boss never does).
  void _come(PipFoe kind, {required bool hits}) {
    foe = kind;
    _struck = 0;
    _recoil = -1;
    bugAt = shift + roomWidth;
    _hitter = hits && kind != PipFoe.boss;
    _fleeing = false;
    if (kind == PipFoe.boss) _bossCame = true;
  }

  /// What comes next: a bug mostly; a beetle or a spider now and then;
  /// the boss, rarely, while one may come.
  PipFoe _pick() {
    if (bossDue && !_bossCame && random.nextDouble() < bossChance) {
      return PipFoe.boss;
    }
    if (snowFoes && random.nextDouble() < snowmanChance) return PipFoe.snowman;
    final r = random.nextDouble();
    if (r < spiderChance) return PipFoe.spider;
    if (r < spiderChance + beetleChance) return PipFoe.beetle;
    return PipFoe.bug;
  }

  /// Round 65: a battery given while he's out, flying from where it was
  /// dropped to him (he catches it without stopping); seconds into it.
  double? _batteryFrom;
  double _batteryT = 0;
  static const batteryFlight = 0.7;

  /// He can catch one now (one at a time).
  bool get canCatch => _batteryFrom == null;

  /// A battery dropped at [left] (on the screen) flies to him.
  void catchBattery(double left) {
    _batteryFrom = left;
    _batteryT = 0;
  }

  /// The flying battery: its left edge and height on the screen, or null.
  (double, double)? get battery {
    final from = _batteryFrom;
    if (from == null) return null;
    final p = (_batteryT / batteryFlight).clamp(0.0, 1.0);
    final to = x + PipBrain.width / 2 - PipBrain.batteryWidth / 2;
    return (
      from + (to - from) * p,
      PipBrain.dropHeight * (1 - p) + 8 * p + 14 * math.sin(math.pi * p),
    );
  }

  /// Moves on by [dt] seconds.
  void step(double dt) {
    t += dt;
    clock += dt;
    if (_batteryFrom != null) {
      _batteryT += dt;
      if (_batteryT >= batteryFlight) {
        _batteryFrom = null;
        buzzes.add(PipBuzz.light);
      }
    }
    shift += speed * dt;
    drop += _dropSpeed * dt;
    if (skiing) _stepSlope(dt);
    _stepBug(dt);
    final tavern = tavernAt;
    if (tavern != null && tavern + tavernWidth - shift < -2) tavernAt = null;
    switch (phase) {
      case RunPhase.cheer:
        if (t >= cheerTime) _to(RunPhase.toCentre);
      case RunPhase.toCentre:
        if (_walkTo(centre, dt)) {
          if (skiing) {
            facingRight = true;
            _go();
            _to(RunPhase.running);
          } else {
            _to(RunPhase.drawing);
          }
        }
      case RunPhase.drawing:
        facingRight = true;
        if (t >= drawTime) {
          _sheathed = false;
          _go();
          _to(RunPhase.running);
        }
      case RunPhase.toGear:
        if (_walkTo(gearX + 6, dt)) {
          facingRight = false;
          _to(_geared ? RunPhase.putGear : RunPhase.takeGear);
        }
      case RunPhase.takeGear:
        if (t >= gearTime / 2) _geared = true;
        // Round 72: skis on, straight down the slope (not walked over).
        if (t >= gearTime) {
          facingRight = true;
          _go();
          _to(RunPhase.running);
        }
      case RunPhase.putGear:
        if (t >= gearTime / 2) _geared = false;
        if (t >= gearTime) _to(RunPhase.done);
      case RunPhase.skiFall:
        final p = (t / fallTime).clamp(0.0, 1.0);
        // Round 72: the ski lands beside him; he clicks back in where
        // he is (no walking over).
        skiAt = _skiFrom + 4 * _ease(p);
        if (t >= fallTime) _to(RunPhase.skiOn);
      case RunPhase.toSki:
        if (_walkTo(skiAt! - PipBrain.width / 2, dt, fast: true)) {
          _to(RunPhase.skiOn);
        }
      case RunPhase.skiOn:
        if (t >= skiOnTime / 2) skiAt = null;
        if (t >= skiOnTime) {
          _go();
          _to(RunPhase.running);
        }
      case RunPhase.running:
        _run(dt);
      case RunPhase.knocked:
        final p = (t / knockTime).clamp(0.0, 1.0);
        x = _knockFrom - 12 * p;
        if (t >= knockTime) {
          buzzes.add(PipBuzz.heavy);
          _to(RunPhase.down);
        }
      case RunPhase.down:
        if (t >= downTime) _to(RunPhase.toSword);
      case RunPhase.toSword:
        final at = swordAt ?? shift + x;
        if (_walkTo(at - shift - 1, dt, fast: true)) {
          facingRight = true;
          _to(RunPhase.pickUp);
        }
      case RunPhase.pickUp:
        if (t >= pickTime / 2) swordAt = null;
        if (t >= pickTime) _to(RunPhase.back);
      case RunPhase.back:
        if (_walkTo(centre, dt, fast: true)) {
          facingRight = true;
          if (_sheathed && !skiing) {
            _to(RunPhase.drawing);
          } else {
            _go();
            _to(RunPhase.running);
          }
        }
      case RunPhase.arriving:
        final seat = tavernAt! + seatOffset - shift;
        if (seat <= _seatX(centre)) {
          speed = 0;
          _to(RunPhase.toSeat);
        }
      case RunPhase.toSeat:
        if (t >= sheatheTime) _sheathed = true;
        if (_walkTo(tavernAt! + seatOffset - shift, dt) && t >= sheatheTime) {
          facingRight = false;
          plate = 0;
          _to(RunPhase.sitting);
        }
      case RunPhase.sitting:
        plate = math.min(1, (plate ?? 0) + dt / plateFlight);
        if (plate! >= 1) _eat(dt);
        if (!_wantBreak || _wantEnd) _to(RunPhase.standUp);
      case RunPhase.standUp:
        if (t >= standUpTime) {
          plate = null;
          _to(_wantEnd ? RunPhase.ending : RunPhase.back);
        }
      case RunPhase.ending:
        speed = math.max(0, speed - runSpeed * dt / endTime);
        _dropSpeed = math.max(0, _dropSpeed - skiSpeed * dt / endTime);
        if (t >= endTime) {
          speed = 0;
          _dropSpeed = 0;
          _sheathed = true;
          _to(skiing && _geared ? RunPhase.toGear : RunPhase.done);
        }
      case RunPhase.toShelter:
        speed = math.max(0, speed - runSpeed * dt / shelterSlow);
        if (t >= sheatheTime) _sheathed = true;
        if (t >= shelterSlow) {
          speed = 0;
          tent ??= PipTent((x + PipBrain.width / 2 - PipTent.width / 2)
              .clamp(0, math.max(0, roomWidth - PipTent.width))
              .toDouble());
          _to(RunPhase.sheltering);
        }
      case RunPhase.sheltering:
        final tent = this.tent!;
        if (storm && !_wantEnd) {
          tent.repitch();
        } else {
          tent.pack();
        }
        tent.step(dt);
        if (tent.gone) {
          this.tent = null;
          if (_wantEnd) {
            _to(RunPhase.done);
          } else {
            _to(RunPhase.drawing);
          }
        }
      case RunPhase.done:
        break;
    }
  }

  double _knockFrom = 0;

  void _run(double dt) {
    if (skiing) {
      _ski(dt);
      return;
    }
    // Round 75: slower in the fog.
    speed = runSpeed * pace;
    facingRight = true;
    x = centre;
    // Round 75: a storm: he stops and shelters in his tent (a foe coming
    // runs off first).
    if (storm && _swing < 0 && tavernAt == null && !_wantEnd) {
      if (bugAt != null) _fleeing = true;
      _to(RunPhase.toShelter);
      return;
    }
    if (_wantEnd && _swing < 0) {
      // A bug still coming scurries off.
      if (bugAt != null) _fleeing = true;
      _to(RunPhase.ending);
      return;
    }
    if (_wantBreak && bugAt == null && tavernAt == null) {
      tavernAt = shift + roomWidth + 2;
      _to(RunPhase.arriving);
      return;
    }
    if (_swing >= 0) {
      _swing += dt;
      if (_swing >= swingTime) {
        _swing = -1;
        _struck++;
        final boss = foe == PipFoe.boss;
        if (_struck < foe.hits) {
          // Round 73: not down yet: it staggers back, then comes again.
          _recoil = 0;
          buzzes.add(boss ? PipBuzz.medium : PipBuzz.light);
          return;
        }
        _poofAt = bugAt! + foe.width / 2;
        _lastDown = _poofAt;
        _poofT = 0;
        _poofSize = foe.width / PipBrain.bugWidth;
        bugAt = null;
        defeats.add(foe);
        buzzes.add(boss ? PipBuzz.heavy : PipBuzz.light);
      }
      return;
    }
    final bug = bugAt;
    if (bug == null) {
      _nextBug -= dt;
      if (_nextBug <= 0 && spawns && !_wantBreak && !_wantEnd) {
        _come(_pick(), hits: random.nextDouble() < hitChance);
        _nextBug = bugFrom + random.nextDouble() * bugSpread;
      }
      return;
    }
    if (_recoil >= 0) return;
    final gap = bug - shift - (x + PipBrain.width);
    if (_hitter && gap <= 1) {
      // It gets him: knocked back, the sword flying off behind him.
      _knockFrom = x;
      speed = 0;
      _swordFrom = shift + x + PipBrain.width;
      swordAt = shift + math.max(2, x - 24);
      _fleeing = true;
      buzzes.add(PipBuzz.medium);
      _to(RunPhase.knocked);
    } else if (!_hitter && gap <= PipBrain.reach) {
      _swing = 0;
    }
  }

  /// Skiing down: the slope rising past him, bumps, a fall now and then;
  /// his break and the end as when running.
  void _ski(double dt) {
    facingRight = true;
    // Round 72: a gentle slalom, eased into from where he set off.
    final lane = centre + swayAt(drop);
    x += (lane - x) * math.min(1, dt * 3);
    _dropSpeed = skiSpeed;
    speed = tavernAt == null ? 0 : runSpeed;
    if (_wantEnd) {
      _to(RunPhase.ending);
      return;
    }
    if (_wantBreak && tavernAt == null) {
      // The hut slides in from the side, the slope still.
      _dropSpeed = 0;
      speed = runSpeed;
      tavernAt = shift + roomWidth + 2;
      _to(RunPhase.arriving);
      return;
    }
    _nextFall -= dt;
    if (_nextFall <= 0 && _hop < 0) {
      _nextFall = fallFrom + random.nextDouble() * fallSpread;
      _dropSpeed = 0;
      _skiFrom = x + PipBrain.width;
      skiAt = _skiFrom;
      buzzes.add(PipBuzz.medium);
      _to(RunPhase.skiFall);
    }
  }

  void _stepSlope(double dt) {
    if (_hop >= 0) {
      _hop += dt;
      if (_hop >= hopTime) {
        _hop = -1;
        buzzes.add(PipBuzz.light);
      }
    }
    if (_dropSpeed <= 0) return;
    // Trees and flags, now and then, on either side of him.
    _nextThing -= dt;
    if (_nextThing <= 0) {
      _nextThing = 0.25 + random.nextDouble() * 0.45;
      _placeThing(drop + 10);
    }
    slope.removeWhere((s) => drop - s.at > farthest);
    // A bump under him now and then: a hop as it passes his feet.
    _nextBump -= dt;
    if (_nextBump <= 0 && _bumpAt == null && phase == RunPhase.running) {
      _nextBump = 6 + random.nextDouble() * 8;
      _bumpAt = drop + 10;
    }
    final bump = _bumpAt;
    if (bump != null) {
      final up = drop - bump;
      if (up >= 0 && _hop < 0 && phase == RunPhase.running) _hop = 0;
      if (up > farthest) _bumpAt = null;
    }
  }

  /// A tree or a flag at [at] on the slope, either side of his lane, some
  /// beyond the screen's edges (they come in toward the middle as they
  /// go).
  void _placeThing(double at) {
    final room = roomWidth * 1.6;
    for (var i = 0; i < 6; i++) {
      final tx = -roomWidth * 0.3 + random.nextDouble() * room;
      if (tx > centre - 14 && tx < centre + PipBrain.width + 10) continue;
      final kind = random.nextDouble() < 0.6
          ? SlopeThing.tree
          : (random.nextBool() ? SlopeThing.redFlag : SlopeThing.blueFlag);
      slope.add((x: tx, at: at, kind: kind));
      return;
    }
  }

  /// The bump: how high above the ground on the screen (it rises past
  /// him), or null.
  double? get bump {
    final b = _bumpAt;
    return b == null ? null : drop - b;
  }

  void _stepBug(double dt) {
    if (_poofAt != null) {
      _poofT += dt;
      if (_poofT >= poofTime * math.sqrt(_poofSize)) _poofAt = null;
    }
    for (var i = xpPops.length - 1; i >= 0; i--) {
      final (xp, at, t) = xpPops[i];
      if (t + dt >= xpPopTime) {
        xpPops.removeAt(i);
      } else {
        xpPops[i] = (xp, at, t + dt);
      }
    }
    final bug = bugAt;
    if (bug == null) return;
    if (_recoil >= 0) {
      // Staggering back from a strike (Round 73: away from him, the
      // ground's run too).
      _recoil += dt;
      bugAt = bug + (speed + recoilSpeed * (1 - _recoil / recoilTime)) * dt;
      if (_recoil >= recoilTime) _recoil = -1;
    } else if (_fleeing) {
      // Scurrying off (Round 73: faster than the ground, so one that got
      // him is gone even once he's running again).
      bugAt = bug + (speed + fleeSpeed) * dt;
      if (bugAt! - shift > roomWidth) bugAt = null;
    } else if (_swing < 0) {
      bugAt = bug - foe.crawl * dt;
    } else {
      // Struck at: it stands its ground where he reached it.
      bugAt = bug + speed * dt;
    }
  }

  /// Walks to [to]; true once there.
  bool _walkTo(double to, double dt, {bool fast = false}) {
    final distance = (fast ? walkSpeed : PipBrain.speed) * dt;
    if ((to - x).abs() <= distance) {
      x = to;
      return true;
    }
    facingRight = to > x;
    x += to > x ? distance : -distance;
    return false;
  }

  /// Walking or running (his legs step).
  bool get stepping => switch (phase) {
        // Round 67: on skis he glides.
        RunPhase.running || RunPhase.arriving => !skiing,
        RunPhase.toGear || RunPhase.toSki => true,
        RunPhase.ending || RunPhase.toShelter => speed > 2,
        RunPhase.toCentre ||
        RunPhase.toSword ||
        RunPhase.back ||
        RunPhase.toSeat =>
          true,
        _ => false,
      };

  /// How quick his steps are (1: walking).
  double get stepRate => phase == RunPhase.running ||
          phase == RunPhase.arriving ||
          phase == RunPhase.ending
      ? 1.8
      : phase == RunPhase.toSword || phase == RunPhase.back
          ? 1.3
          : 1;

  /// How high off the ground (a knock's arc, or his seat).
  double get lift => switch (phase) {
        RunPhase.running when _hop >= 0 =>
          4 * math.sin(math.pi * (_hop / hopTime).clamp(0, 1)),
        RunPhase.knocked => 7 * math.sin(math.pi * (t / knockTime).clamp(0, 1)),
        RunPhase.sitting => seatHeight,
        RunPhase.standUp => seatHeight * (1 - t / standUpTime) +
            2 * math.sin(math.pi * t / standUpTime),
        _ => 0,
      };

  /// Round 83: sitting on it, his feet over its front (no longer standing
  /// on its top): his body on its top, a row under his bench's 3.
  static const seatHeight = 2.0;

  /// Crouched picking up the sword: 0 to 1.
  double? get crouch => switch (phase) {
        RunPhase.pickUp => t / pickTime,
        RunPhase.skiOn => t / skiOnTime,
        RunPhase.takeGear || RunPhase.putGear => t / gearTime,
        _ => null,
      };

  /// Tumbling back (radians) as he's knocked.
  double get spin => switch (phase) {
        RunPhase.knocked => -2 * math.pi * (t / knockTime).clamp(0.0, 1.0),
        // Round 67: a fall on skis, head over heels forward.
        RunPhase.skiFall =>
          2 * math.pi * _ease((t / (fallTime * 0.6)).clamp(0.0, 1.0)),
        _ => 0,
      };

  /// A puff of snow where he fell: 0 → 1, or null.
  double? get snowPuff => phase == RunPhase.skiFall && t >= fallTime * 0.5
      ? ((t - fallTime * 0.5) / (fallTime * 0.5)).clamp(0.0, 1.0)
      : null;

  /// His skis on his feet (both, or one while the other's off) and his
  /// poles in hand.
  bool get skisOn =>
      geared &&
      phase != RunPhase.skiFall &&
      // At the hut, they lean on its wall.
      phase != RunPhase.sitting &&
      phase != RunPhase.standUp;
  bool get oneSki => skiAt != null;

  /// The sword in his hand: (hand x, height, angle, size) on the screen,
  /// as `PipBrain.sword`; null: not in his hand.
  (double, double, double, double)? get sword {
    if (skiing && phase != RunPhase.cheer) return null;
    final hand = facingRight
        ? x + PipBrain.width - PipBrain.bodyInset + 2
        : x + PipBrain.bodyInset - 2;
    final forward = facingRight ? 1.0 : -1.0;
    switch (phase) {
      case RunPhase.cheer:
        // Held up high over his head, pointing at the sky.
        final double size = (t / 0.3).clamp(0.0, 1.0);
        return (x + PipBrain.width / 2, PipBrain.height + 6.0, 0, size);
      case RunPhase.drawing:
        return (hand, 7, forward * 0.3, (t / drawTime).clamp(0.0, 1.0));
      case RunPhase.running || RunPhase.arriving || RunPhase.back:
        if (_sheathed) return null;
        final angle = _swing >= 0
            ? 0.3 + 1.5 * _ease(_swing / swingTime)
            : 0.3 + 0.08 * math.sin(clock * 9);
        return (hand, 7, forward * angle, 1);
      case RunPhase.pickUp when t >= pickTime / 2:
        return (hand, 6, forward * 0.3, 1);
      case RunPhase.toSeat:
        if (_sheathed) return null;
        return (hand, 7, forward * 0.3, 1 - (t / sheatheTime).clamp(0.0, 1.0));
      case RunPhase.ending:
        if (_sheathed) return null;
        return (hand, 7, forward * 0.3, 1 - (t / endTime).clamp(0.0, 1.0));
      case RunPhase.toShelter:
        if (_sheathed) return null;
        return (hand, 7, forward * 0.3, 1 - (t / sheatheTime).clamp(0.0, 1.0));
      default:
        return null;
    }
  }

  /// The sword flying off or lying on the ground: (its grip's middle x,
  /// height above the ground, angle) on the screen; null: in his hand.
  /// Round 76: it turns over twice and a quarter in the air, up in an
  /// arc and down, and lands flat; never into the ground (it used to
  /// come down point first, through it, then flip flat).
  (double, double, double)? get lyingSword {
    final at = swordAt;
    if (at == null) return null;
    if (phase == RunPhase.knocked) {
      final p = (t / knockTime).clamp(0.0, 1.0);
      final sx = _swordFrom + (at - _swordFrom) * p - shift;
      final angle = landedAngle * _easeOut(p);
      final arc = 7 * (1 - p) + 14 * math.sin(math.pi * p);
      return (sx, math.max(arc, swordBelow(angle)), angle);
    }
    return (at - shift, swordBelow(landedAngle), landedAngle);
  }

  /// How it lies: flat (pointing back, the way it flew), after two turns.
  static const landedAngle = -2.5 * math.pi;

  /// How far below its grip's middle the sword reaches, turned by [angle]
  /// (0: pointing up): its blade 10.5 pixels up from there, its pommel 2.5
  /// down, 5 wide.
  static double swordBelow(double angle) {
    var low = double.negativeInfinity;
    for (final px in const [-2.5, 2.5]) {
      for (final py in const [-10.5, 2.5]) {
        low = math.max(low, px * math.sin(angle) + py * math.cos(angle));
      }
    }
    return low;
  }

  static double _easeOut(double p) => 1 - math.pow(1 - p, 2).toDouble();

  /// The bug: its left edge on the screen, its legs up, walking right
  /// (running off); null: none.
  (double, bool, bool)? get bug {
    final b = bugAt;
    if (b == null) return null;
    return (b - shift, (clock * 8).floor().isEven, _fleeing);
  }

  /// A struck bug's poof: its middle on the screen and 0 → 1.
  (double, double)? get poof {
    final p = _poofAt;
    if (p == null) return null;
    return (p - shift, _poofT / (poofTime * math.sqrt(_poofSize)));
  }

  /// How big the poof is (Round 73: a boss's bigger).
  double get poofSize => _poofSize;

  /// Strikes the foe coming can still take (Round 73), and whether it's
  /// staggering from one (it flashes).
  int get foeHitsLeft => foe.hits - _struck;
  bool get foeFlash => _recoil >= 0 && (_recoil * 20).floor().isEven;

  /// XP gained, rising: (how much, its middle on the screen, 0 → 1).
  Iterable<(int, double, double)> get xpRising => [
        for (final (xp, at, t) in xpPops) (xp, at, t / xpPopTime),
      ];

  /// The tavern's left edge on the screen, or null.
  double? get tavern {
    final at = tavernAt;
    return at == null ? null : at - shift;
  }

  /// The plate: (its middle x, height above the ground, meal left 0–1);
  /// flying out of the window to the table, then eaten as his break goes.
  (double, double, double)? get plateAt {
    final p = plate;
    final tav = tavern;
    if (p == null || tav == null) return null;
    final fromX = tav + windowMiddle, fromY = 10.0;
    final toX = tav + tableLeft + tableWidth / 2, toY = tableHeight.toDouble();
    final px = fromX + (toX - fromX) * p;
    final py = fromY + (toY - fromY) * p + 5 * math.sin(math.pi * p);
    return (px, py, phase == RunPhase.sitting ? mealLeft : 0);
  }

  /// A fall now (a preview's, tests and pictures).
  void fallNow() => _nextFall = 0;

  /// Round 74: his meal (or hot chocolate) bite by bite (sip by sip):
  /// every [biteEvery] seconds once the plate's down his hand takes a
  /// bite from it to his mouth ([biteLength]: there at [mouthAt], then
  /// chewing; a mug is carried back after a sip); [bitesPerMeal] finish
  /// it. Not watched, it's gone by a quarter of the way into his break.
  static const biteEvery = 3.0;
  static const biteLength = 1.4;
  static const mouthAt = 0.5;
  static const bitesPerMeal = 6;
  double _waited = biteEvery - biteLength - 0.6;
  int _bites = 0;

  /// Seconds into the bite going on; null: none.
  double? biteT;

  /// Where his mouth is from his left edge (he faces the table, left),
  /// and how high.
  static const mouthX = 10.0;
  static const mouthUp = 6.0;

  void _eat(double dt) {
    final bite = biteT;
    if (bite == null) {
      if (mealLeft <= 0) return;
      _waited += dt;
      if (_waited >= biteEvery - biteLength) {
        _waited = 0;
        biteT = 0;
      }
      return;
    }
    final next = bite + dt;
    if (bite < mouthAt && next >= mouthAt) _bites++;
    biteT = next >= biteLength ? null : next;
  }

  /// What's left of his meal (or mug), 1 to 0.
  double get mealLeft => (1 - math.max(breakDone * 4, _bites / bitesPerMeal))
      .clamp(0.0, 1.0)
      .toDouble();

  /// Chewing (or sipping): his mouth open and shut.
  bool get chewing {
    final b = biteT;
    if (b == null || b < mouthAt) return false;
    // A sip: the mug at his mouth.
    if (skiing) return b < mouthAt + 0.4;
    return b < mouthAt + 0.7;
  }

  /// His hand taking a bite (or the mug) to his mouth: (x, height above
  /// the ground, size 0–1, carrying a bite) on the screen; null: none.
  (double, double, double, bool)? get hand {
    final b = biteT;
    final from = plateAt;
    if (b == null || from == null) return null;
    final (px, py, _) = from;
    final mx = x + mouthX, my = mouthUp;
    (double, double) along(double p) =>
        (px + (mx - px) * _ease(p), py + 1 + (my - py - 1) * _ease(p));
    if (b < mouthAt) {
      final (hx, hy) = along(b / mouthAt);
      return (hx, hy, math.min(1, b / 0.12), true);
    }
    if (skiing) {
      // Held to his mouth, then carried back.
      final back = b - mouthAt - 0.4;
      if (back < 0) return (mx, my, 1, true);
      final (hx, hy) = along(1 - back / (biteLength - mouthAt - 0.4));
      return (hx, hy, 1, true);
    }
    // The bite in his mouth: the hand goes.
    final gone = (b - mouthAt) / 0.25;
    if (gone >= 1) return null;
    return (mx, my, 1 - gone, false);
  }

  static double _ease(double p) {
    final q = p.clamp(0.0, 1.0);
    return q < 0.5 ? 2 * q * q : 1 - math.pow(-2 * q + 2, 2) / 2;
  }
}
