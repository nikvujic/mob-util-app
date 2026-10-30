part of 'pip_brain.dart';

/// Round 75: the weather in his field, as his brain lives it
/// (`core/pip_weather.dart` says what each weather does): his tent in a
/// storm, his umbrella in the rain, the weather's events, the snowman
/// he built, a snowball's splat, and the weather coming in.
class _PipWeatherState {
  /// The weather now (the room says), and whether it's been told yet
  /// (the first is simply there, not seen coming in).
  WeatherKind? weather;
  bool known = false;

  /// Seconds since it changed (it comes in over [comeIn]).
  double since = comeIn;

  /// He noticed it change: he looks up when he's free to.
  bool noticed = false;

  PipTent? tent;
  final umbrella = PipUmbrella();
  PipSnowman? snowman;
  PipSplat? splat;

  /// The event going on, its phase and seconds into that phase; where
  /// it's going on (the puddle's middle, the snowman's left edge).
  PipWeatherEvent? event;
  int phase = 0;
  double t = 0;
  double at = 0;

  /// A battery flying into his tent: where it was dropped, seconds in.
  double? flyFrom;
  double flyT = 0;

  /// The puddle's splash (seconds in), at [at].
  double? splash;
}

/// The weather's animations in Pip Home's list, as events.
const _weatherAnimations = {
  PipAnimation.puddle: PipWeatherEvent.puddle,
  PipAnimation.twirl: PipWeatherEvent.twirl,
  PipAnimation.handOut: PipWeatherEvent.handOut,
  PipAnimation.flakes: PipWeatherEvent.flakes,
  PipAnimation.snowman: PipWeatherEvent.snowman,
  PipAnimation.snowball: PipWeatherEvent.snowball,
  PipAnimation.lost: PipWeatherEvent.lost,
};

/// What he does under his tent while he's in it: asleep, off, up (in
/// [PipActivity.sheltering]), and on the way between them.
const _inTent = {
  PipActivity.sheltering,
  PipActivity.fallingAsleep,
  PipActivity.asleep,
  PipActivity.stirring,
  PipActivity.wakingUp,
  PipActivity.poweringOff,
  PipActivity.off,
  PipActivity.poweringOn,
};

/// Where he is in his field, not out (on his adventure, on the bus) nor
/// coming into it: the weather's his.
const _awayOrArriving = {
  PipActivity.egg,
  PipActivity.hatching,
  PipActivity.spawning,
  PipActivity.falling,
  PipActivity.thrown,
  PipActivity.adventuring,
  PipActivity.riding,
  // Round 128: at his quest's work (his rain hat's for the wet).
  PipActivity.questing,
};

/// While these, his umbrella's up in the rain (his hands free for it).
const _umbrellaWhile = {
  PipActivity.standing,
  PipActivity.walking,
  PipActivity.lookingUp,
  PipActivity.weatherEvent,
};

extension PipBrainWeather on PipBrain {
  /// The weather event [animation] plays, if it's one (Round 75).
  static PipWeatherEvent? eventOf(PipAnimation animation) =>
      _weatherAnimations[animation];

  /// The weather in his field now (the room sets it from its scene).
  WeatherKind? get weather => _wx.weather;
  set weather(WeatherKind? next) {
    final wx = _wx;
    if (!wx.known) {
      wx.known = true;
      wx.weather = next;
      return;
    }
    if (next == wx.weather) return;
    wx.weather = next;
    wx.since = 0;
    wx.noticed = true;
  }

  /// How far the weather has come in, 0 to 1 (rain and snow thicken).
  double get weatherIn => math.min(1, _wx.since / comeIn);

  /// Snow in his field to play in: falling, or a ski day's.
  bool get _snowyField => _wx.weather == WeatherKind.snow || snowing;

  /// His tent, if it's up (or going up or down): at home, or by the
  /// path on his day out.
  PipTent? get tent =>
      activity == PipActivity.adventuring ? _run?.tent : _wx.tent;

  /// Hidden in his tent (it's up enough, him in it).
  bool get inTent => activity == PipActivity.adventuring
      ? _run?.inTent ?? false
      : (_wx.tent?.hides ?? false) && _inTent.contains(activity);

  /// Peeking out of his tent's door now and then, awake in it.
  bool get peeking =>
      activity == PipActivity.sheltering &&
      _wx.tent?.phase == TentPhase.up &&
      (_t % 6) > 4.5;

  /// How open his umbrella is (0: none).
  double get umbrella => _wx.umbrella.open;

  /// The snowman he built, and a snowball's splat on the glass.
  PipSnowman? get snowman => _wx.snowman;
  PipSplat? get splat => _wx.splat;

  /// The weather event going on, if any.
  PipWeatherEvent? get weatherEvent =>
      activity == PipActivity.weatherEvent ? _wx.event : null;

  /// Rain's puddles in his field (their middles), for him to jump in.
  List<double> get puddles => !atHome &&
          (_wx.weather == WeatherKind.rain || _wx.weather == WeatherKind.storm)
      ? [
          for (final at in const [0.16, 0.5, 0.84]) roomWidth * at
        ]
      : const [];

  /// A puddle's splash: (its middle, 0 → 1); null: none.
  (double, double)? get splash {
    final s = _wx.splash;
    return s == null ? null : (_wx.at, s / _splashTime);
  }

  /// A battery flying into his tent: (left edge, height), or null.
  (double, double)? get _tentBattery {
    final from = _wx.flyFrom;
    final tent = _wx.tent;
    if (from == null || tent == null) return null;
    final p = math.min(1.0, _wx.flyT / _flyInTime);
    final to = tent.left + PipTent.width / 2 - PipBrain.batteryWidth / 2;
    return (
      from + (to - from) * p,
      PipBrain.dropHeight * (1 - p) + 4 * p + 12 * math.sin(math.pi * p),
    );
  }

  /// His hand held out (drizzle), or scooping, winding up, throwing (a
  /// snowball): (x, height above the ground); null: none.
  (double, double)? get weatherHand {
    if (activity != PipActivity.weatherEvent) return null;
    final side = PipBrain.handBesideOf(x, facingRight);
    return switch (_wx.event) {
      PipWeatherEvent.handOut => (side + (facingRight ? 2 : -2), 8),
      PipWeatherEvent.snowball => switch (_wx.phase) {
          0 => (side, 1),
          1 => (side + (facingRight ? -3 : 3), 14),
          2 => (side + (facingRight ? 3 : -3), 15),
          _ => null,
        },
      PipWeatherEvent.snowman when _wx.phase == 1 => (
          side + (facingRight ? 1 : -1),
          4
        ),
      _ => null,
    };
  }

  /// A snowball in his hand (scooped, wound up).
  bool get holdingSnowball =>
      activity == PipActivity.weatherEvent &&
      _wx.event == PipWeatherEvent.snowball &&
      (_wx.phase == 1 || (_wx.phase == 0 && _wx.t > _scoopTime / 2));

  /// A drop falling onto his held-out hand (drizzle): 0 → 1; null: none.
  double? get dropOnHand {
    if (weatherEvent != PipWeatherEvent.handOut) return null;
    final p = (_t - _dropAt) / 0.5;
    return p >= 0 && p <= 1 ? p : null;
  }

  /// Flakes drifting to his tongue (snow): 0 → 1 through it.
  double? get flakesIn =>
      weatherEvent == PipWeatherEvent.flakes ? _t / _flakesTime : null;

  /// Lost in the fog: his question mark.
  bool get lost => weatherEvent == PipWeatherEvent.lost;

  /// Twirling his umbrella: its turn (radians).
  double get umbrellaTurn => weatherEvent == PipWeatherEvent.twirl
      ? 2 * math.pi * (_t / _twirlTime) * 2
      : 0;

  static const _splashTime = 0.7;
  static const _flyInTime = 0.7;
  static const _lookUpTime = 1.4;
  static const _crouchTime = 0.25;
  static const _jumpTime = 0.55;
  static const _delightTime = 0.8;
  static const _twirlTime = 2.4;
  static const _handOutTime = 3.0;
  static const _dropAt = 1.2;
  static const _flakesTime = 3.2;
  static const _buildTime = 7.0;
  static const _admireTime = 1.2;
  static const _scoopTime = 0.5;
  static const _windUpTime = 0.4;
  static const _throwTime = 0.25;
  static const _laughTime = 1.0;
  static const _lostTime = 3.0;

  /// Starts [event] (a free moment, or Pip Home's list).
  void _startWeatherEvent(PipWeatherEvent event) {
    final wx = _wx;
    wx.event = event;
    wx.phase = 0;
    wx.t = 0;
    // Busy with it: no looking up at the weather after.
    wx.noticed = false;
    switch (event) {
      case PipWeatherEvent.puddle:
        // The nearest puddle (where rain's would be).
        final spots = [
          for (final at in const [0.16, 0.5, 0.84]) roomWidth * at
        ];
        final middle = x + PipBrain.width / 2;
        spots.sort((a, b) => (a - middle).abs().compareTo((b - middle).abs()));
        wx.at = spots.first;
        _target = (wx.at - PipBrain.width / 2).clamp(0, _maxX).toDouble();
      case PipWeatherEvent.snowman:
        // Room beside him for it, on the side with more room.
        final right = x + PipBrain.width + PipSnowman.width + 2 <= roomWidth &&
            (x < roomWidth / 2 || x - PipSnowman.width - 2 < 0);
        wx.at = right ? x + PipBrain.width + 1 : x - PipSnowman.width - 1;
        facingRight = right;
        wx.phase = 1;
        // A snowman there already goes (one at a time).
        wx.snowman = PipSnowman(wx.at);
      default:
    }
    _start(PipActivity.weatherEvent);
  }

  /// A weather event instead of something else, now and then. True if
  /// one started.
  bool _maybeWeatherEvent() {
    final events = weatherEventsIn(_wx.weather, snowy: snowing)
        .where((e) =>
            // One snowman at a time; a twirl needs his umbrella.
            !(e == PipWeatherEvent.snowman && _wx.snowman != null) &&
            !(e == PipWeatherEvent.twirl && !_wx.umbrella.shown))
        .toList();
    if (events.isEmpty || random.nextDouble() >= weatherEventShare) {
      return false;
    }
    _startWeatherEvent(events[random.nextInt(events.length)]);
    return true;
  }

  void _stepWeatherEvent(double dt) {
    final wx = _wx;
    wx.t += dt;
    void next() {
      wx.phase++;
      wx.t = 0;
    }

    switch (wx.event) {
      case PipWeatherEvent.puddle:
        switch (wx.phase) {
          case 0: // walking to it
            final distance = pace * dt;
            if ((_target - x).abs() <= distance) {
              x = _target;
              next();
            } else {
              facingRight = _target > x;
              x += _target > x ? distance : -distance;
            }
          case 1: // a crouch
            if (wx.t >= _crouchTime) next();
          case 2: // up, and down in it
            if (wx.t >= _jumpTime) {
              wx.splash = 0;
              _buzzes.add(PipBuzz.light);
              next();
            }
          default:
            if (wx.t >= _delightTime) _stand();
        }
      case PipWeatherEvent.twirl:
        facingRight = (_t / (_twirlTime / 4)).floor().isEven;
        if (_t >= _twirlTime) _stand();
      case PipWeatherEvent.handOut:
        if (_t >= _handOutTime) _stand();
      case PipWeatherEvent.flakes:
        if (_t >= _flakesTime) _stand();
      case PipWeatherEvent.snowman:
        switch (wx.phase) {
          case 1: // building
            wx.snowman?.built = math.min(1, wx.t / _buildTime);
            if (wx.t >= _buildTime) {
              _buzzes.add(PipBuzz.light); // Round 98: done
              facingRight = !facingRight;
              next();
            }
          default: // stepping back to look at it
            if (wx.t >= _admireTime) _stand();
        }
      case PipWeatherEvent.snowball:
        switch (wx.phase) {
          case 0:
            if (wx.t >= _scoopTime) next();
          case 1:
            if (wx.t >= _windUpTime) {
              final hand = PipBrain.handBesideOf(x, facingRight);
              wx.splat = PipSplat(
                fromX: hand,
                fromUp: 15,
                x: roomWidth * (0.25 + 0.5 * random.nextDouble()),
                y: skyRows * (0.2 + 0.5 * random.nextDouble()),
              );
              next();
            }
          case 2:
            if (wx.t >= _throwTime) {
              // Round 98: it splats on the glass, at you.
              _buzzes.add(PipBuzz.medium);
              next();
            }
          default:
            if (wx.t >= _laughTime) _stand();
        }
      case PipWeatherEvent.lost:
        // Looking this way and that.
        facingRight = (_t / 0.7).floor().isEven;
        if (_t >= _lostTime) _walk();
      case null:
        _stand();
    }
  }

  /// Each step: his tent, umbrella and snowman as the weather goes, the
  /// weather coming in, a splash and a splat, a battery flying in.
  void _stepWeather(double dt) {
    final wx = _wx;
    wx.since += dt;
    final home = !_awayOrArriving.contains(activity);
    // Round 128: in his house he needs no tent or umbrella.
    final storm = wx.weather == WeatherKind.storm && home && !atHome;

    // His tent: up round him when he's free, over him asleep or off;
    // anything going on (an event, his station) finishes first.
    var tent = wx.tent;
    if (tent == null && storm) {
      switch (activity) {
        case PipActivity.standing ||
              PipActivity.walking ||
              PipActivity.lookingUp:
          tent = wx.tent = PipTent(_tentLeft);
          _start(PipActivity.sheltering);
        case PipActivity.fallingAsleep ||
              PipActivity.asleep ||
              PipActivity.poweringOff ||
              PipActivity.off:
          tent = wx.tent = PipTent(_tentLeft);
        default:
      }
    }
    if (tent != null) {
      if (storm) {
        tent.repitch();
      } else {
        tent.pack();
      }
      tent.step(dt);
      // Up (woken, back on) in it: inside, keeping still.
      if (tent.phase != TentPhase.packing &&
          (activity == PipActivity.standing ||
              activity == PipActivity.walking)) {
        _start(PipActivity.sheltering);
      }
      if (tent.gone) {
        wx.tent = null;
        wx.flyFrom = null;
        if (activity == PipActivity.sheltering) _stand();
      }
    }

    // A battery flying into his tent.
    if (wx.flyFrom != null) {
      wx.flyT += dt;
      if (wx.flyT >= _flyInTime) {
        wx.flyFrom = null;
        _buzzes.add(PipBuzz.light);
      }
    }

    // His umbrella, open in the rain while his hands are free for it.
    wx.umbrella.step(dt,
        wanted: home &&
            !atHome &&
            wx.weather == WeatherKind.rain &&
            _umbrellaWhile.contains(activity) &&
            !(activity == PipActivity.weatherEvent &&
                (wx.event == PipWeatherEvent.snowball ||
                    wx.event == PipWeatherEvent.handOut)));

    // The weather changed: he looks up, when he's free to.
    if (wx.noticed &&
        (activity == PipActivity.standing || activity == PipActivity.walking)) {
      wx.noticed = false;
      _start(PipActivity.lookingUp);
    } else if (wx.noticed && !home) {
      wx.noticed = false;
    }

    // His snowman melts once the snow's gone.
    final snowman = wx.snowman;
    if (snowman != null && snowman.built >= 1 && !_snowyField) {
      snowman.melted += dt / PipSnowman.meltTime;
      if (snowman.gone) wx.snowman = null;
    }

    final splash = wx.splash;
    if (splash != null) {
      wx.splash = splash + dt >= _splashTime ? null : splash + dt;
    }
    final splat = wx.splat;
    if (splat != null) {
      splat.t += dt;
      if (splat.gone) wx.splat = null;
    }
  }

  /// Where his tent goes up: round him, inside the room.
  double get _tentLeft => (x + PipBrain.width / 2 - PipTent.width / 2)
      .clamp(0, math.max(0, roomWidth - PipTent.width))
      .toDouble();

  /// The frame for the weather's doings.
  PipFrame get _weatherFrame => switch (activity) {
        PipActivity.lookingUp => PipFrame.oh,
        PipActivity.sheltering => PipFrame.idle,
        _ => switch (_wx.event) {
            PipWeatherEvent.puddle => switch (_wx.phase) {
                0 => _stepFrame,
                1 => PipFrame.tuck,
                2 => PipFrame.oh,
                _ => PipFrame.oh,
              },
            PipWeatherEvent.twirl => (_t / PipBrain.beatTime * 2).floor().isEven
                ? PipFrame.step1
                : PipFrame.step3,
            PipWeatherEvent.handOut =>
              _t < _dropAt + 0.5 ? PipFrame.oh : PipFrame.idle,
            PipWeatherEvent.flakes => PipFrame.oh,
            PipWeatherEvent.snowman =>
              _wx.phase == 1 ? PipFrame.idle : PipFrame.oh,
            PipWeatherEvent.snowball => switch (_wx.phase) {
                0 => PipFrame.tuck,
                3 => PipFrame.oh,
                _ => PipFrame.idle,
              },
            PipWeatherEvent.lost => PipFrame.idle,
            null => PipFrame.idle,
          },
      };

  /// How high he is in the weather's doings (a jump, hops).
  double? get _weatherLift {
    if (activity != PipActivity.weatherEvent) return null;
    double hop(double t, double length, double high) =>
        t < 0 || t >= length ? 0 : high * math.sin(math.pi * t / length);
    return switch (_wx.event) {
      PipWeatherEvent.puddle => switch (_wx.phase) {
          1 => -2,
          2 => hop(_wx.t, _jumpTime, 8),
          _ => 0,
        },
      PipWeatherEvent.twirl =>
        2 * math.sin(math.pi * ((_t / PipBrain.beatTime) % 1)).abs(),
      PipWeatherEvent.flakes => hop(_t - 1.0, 0.4, 3) + hop(_t - 2.2, 0.4, 3),
      PipWeatherEvent.snowball => switch (_wx.phase) {
          0 => -2,
          3 => hop(_wx.t, 0.4, 2) + hop(_wx.t - 0.5, 0.4, 2),
          _ => 0,
        },
      _ => 0,
    };
  }
}
