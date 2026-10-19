import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/core/theme.dart';

/// One system for what shows around Pip and what he may do (Round 35).
void main() {
  DateTime at(int h, int m) => DateTime(2026, 10, 13, h, m);

  test('the parts of the day (Round 59: by the sun, with the seasons)', () {
    final (rise, set) = sunTimesOn(at(12, 0));
    DayPart partAt(double minutes) =>
        dayPartAt(at(minutes ~/ 60, (minutes % 60).floor()));
    expect(dayPartAt(at(0, 0)), DayPart.night);
    expect(partAt(rise - 46), DayPart.night);
    expect(partAt(rise - 44), DayPart.dawn);
    expect(partAt(rise + 19), DayPart.dawn);
    expect(partAt(rise + 21), DayPart.day);
    expect(partAt(set - 21), DayPart.day);
    expect(partAt(set - 19), DayPart.dusk);
    expect(partAt(set + 34), DayPart.dusk);
    expect(partAt(set + 36), DayPart.night);
    expect(dayPartAt(at(23, 59)), DayPart.night);
  });

  test('the sun: its times by the season, as at 45° on the zone\'s meridian',
      () {
    // The phone's clock: an hour later in summer time.
    double summer(DateTime t) {
      final jan = DateTime(t.year).timeZoneOffset;
      final jul = DateTime(t.year, 7).timeZoneOffset;
      return (t.timeZoneOffset - (jan < jul ? jan : jul)).inMinutes.toDouble();
    }

    void near((double, double) times, int rise, int set, DateTime day) {
      expect(times.$1 - summer(day), closeTo(rise, 4), reason: '$day rise');
      expect(times.$2 - summer(day), closeTo(set, 4), reason: '$day set');
    }

    final june = DateTime(2026, 6, 21, 12);
    final december = DateTime(2026, 12, 21, 12);
    final october = DateTime(2026, 10, 15, 12);
    near(sunTimesOn(june), 4 * 60 + 13, 19 * 60 + 51, june);
    near(sunTimesOn(december), 7 * 60 + 37, 16 * 60 + 22, december);
    near(sunTimesOn(october), 6 * 60 + 14, 17 * 60 + 17, october);
    // A phone in Central European time (+1, +2 in summer): the same
    // clock times as on its meridian, summer time an hour later.
    const cet = Duration(hours: 1), cest = Duration(hours: 2);
    final (r, st) = sunTimesOn(october, zone: cest, standardZone: cet);
    expect(r, closeTo(7 * 60 + 14, 4));
    expect(st, closeTo(18 * 60 + 17, 4),
        reason: "Nikola's 18:27 in October: dusk, not day");
    final (wr, ws) = sunTimesOn(december, zone: cet, standardZone: cet);
    expect(wr, closeTo(7 * 60 + 37, 4));
    expect(ws, closeTo(16 * 60 + 22, 4));
    // Nikola's evening: 10 minutes past sunset in October is no longer
    // day (it was, by the fixed hours, till 18:30).
    final (_, set) = sunTimesOn(october);
    final evening = set + 10;
    expect(
        dayPartAt(
            DateTime(2026, 10, 15, evening ~/ 60, (evening % 60).floor())),
        DayPart.dusk);
  });

  test('each part has its own sky', () {
    final skies = {
      for (final part in DayPart.values) PipBackground.field.skyAt(part),
    };
    expect(skies, hasLength(DayPart.values.length));
    expect(PipBackground.field.skyAt(DayPart.night),
        (PipColours.nightTop, PipColours.nightBottom));
  });

  test('what shows where, and when', () {
    final room = PipScene.at(PipPlace.room, at(12, 0));
    expect(room.part, DayPart.day);
    // Round 70: and in October his field's autumn tree and leaves.
    const autumn = {PipProp.trees, PipProp.leaves};
    expect(room.props, {PipProp.sun, PipProp.clouds, ...autumn},
        reason: 'clouds since the room grew (Round 36)');
    expect(PipScene.at(PipPlace.home, at(12, 0)).props,
        {PipProp.sun, PipProp.clouds, ...autumn});
    expect(PipScene.at(PipPlace.room, at(23, 0)).props,
        {PipProp.stars, PipProp.moon, ...autumn});
    final (_, set) = sunTimesOn(at(12, 0));
    final dusk = set + 10;
    expect(
        PipScene.at(PipPlace.home, at(dusk ~/ 60, (dusk % 60).floor())).props,
        {PipProp.moon, PipProp.clouds, PipProp.trees, PipProp.leaves});
  });

  test('never the sun and the moon, or stars by day', () {
    for (final place in PipPlace.values) {
      for (var h = 0; h < 24; h++) {
        final props = PipScene.at(place, at(h, 15)).props;
        expect(props.containsAll({PipProp.sun, PipProp.moon}), isFalse);
        if (props.contains(PipProp.sun)) {
          expect(props, isNot(contains(PipProp.stars)));
        }
      }
    }
  });

  test('every prop shows somewhere', () {
    for (final prop in PipProp.values) {
      expect(prop.places, isNotEmpty, reason: prop.name);
      expect(prop.parts, isNotEmpty, reason: prop.name);
      expect(prop.backgrounds, isNotEmpty, reason: prop.name);
    }
  });

  group('the moon (Round 38)', () {
    test('its real phase: known new and full moons', () {
      // New 11 January 2024 11:57 UTC, full 25 January 17:54 UTC.
      expect(moonAgeAt(DateTime.utc(2024, 1, 11, 11, 57)), closeTo(0, 0.01));
      expect(moonAgeAt(DateTime.utc(2024, 1, 25, 17, 54)), closeTo(0.5, 0.02));
      expect(moonPhaseAt(DateTime.utc(2024, 1, 11, 12)), MoonPhase.none);
      expect(moonPhaseAt(DateTime.utc(2024, 1, 25, 18)), MoonPhase.full);
    });

    test('through a month: none, thin, half, full, half, thin, none', () {
      final start = DateTime.utc(2024, 1, 11, 12);
      final seen = <MoonPhase>[];
      for (var day = 0; day <= 29; day++) {
        final phase = moonPhaseAt(start.add(Duration(days: day)));
        if (seen.isEmpty || seen.last != phase) seen.add(phase);
      }
      expect(seen, [
        MoonPhase.none,
        MoonPhase.thinGrowing,
        MoonPhase.halfGrowing,
        MoonPhase.full,
        MoonPhase.halfShrinking,
        MoonPhase.thinShrinking,
        MoonPhase.none,
      ]);
      expect(MoonPhase.thinGrowing.growing, isTrue);
      expect(MoonPhase.halfShrinking.growing, isFalse);
    });

    test('at a new moon, none in the sky; otherwise there at night', () {
      final newMoon = PipScene.at(PipPlace.room, DateTime.utc(2024, 1, 11, 23));
      expect(newMoon.moon, MoonPhase.none);
      expect(newMoon.props, isNot(contains(PipProp.moon)));
      final full = PipScene.at(PipPlace.room, DateTime(2024, 1, 25, 23));
      expect(full.moon, MoonPhase.full);
      expect(full.props, contains(PipProp.moon));
    });
  });

  test('a background by its stored id; an unknown one is his field', () {
    expect(PipBackground.byId('field'), PipBackground.field);
    expect(PipBackground.byId('moon base'), PipBackground.field);
  });

  test('with no background: no sky, nothing in it', () {
    final off = PipScene.at(PipPlace.home, at(23, 0), background: null);
    expect(off.sky, isNull);
    expect(off.props, isEmpty);
  });

  group('what he may start (the mayStart table)', () {
    test(
        'nothing mid-way: egg, hatching, coming up, falling asleep, '
        'waking, turning off or on, picking up a battery', () {
      for (final doing in [
        PipActivity.egg,
        PipActivity.hatching,
        PipActivity.spawning,
        PipActivity.fallingAsleep,
        PipActivity.wakingUp,
        PipActivity.poweringOff,
        PipActivity.poweringOn,
        PipActivity.fetching,
        // Round 44: at his station, or on his way.
        PipActivity.toStation,
        PipActivity.plugging,
        PipActivity.charging,
        PipActivity.unplugging,
      ]) {
        for (final a in PipAnimation.values) {
          expect(mayStart(doing, a), isFalse,
              reason: '${doing.name} ${a.name}');
        }
      }
    });

    test('up and about: anything but waking or coming back on', () {
      for (final doing in [PipActivity.standing, PipActivity.walking]) {
        for (final a in PipAnimation.values) {
          expect(mayStart(doing, a),
              a != PipAnimation.wakeUp && a != PipAnimation.powerOn,
              reason: '${doing.name} ${a.name}');
        }
      }
    });

    test('asleep: only waking (or running out); off: only back on', () {
      for (final a in PipAnimation.values) {
        expect(mayStart(PipActivity.asleep, a),
            a == PipAnimation.wakeUp || a == PipAnimation.powerOff,
            reason: 'asleep ${a.name}');
        expect(mayStart(PipActivity.off, a), a == PipAnimation.powerOn,
            reason: 'off ${a.name}');
      }
    });

    test('every activity has its row', () {
      for (final doing in PipActivity.values) {
        for (final a in PipAnimation.values) {
          mayStart(doing, a); // exhaustive: compiles only with every row
        }
      }
      expect(PipAnimation.values.where((a) => a.listed).map((a) => a.name), [
        'spawn',
        'hatch',
        'walk',
        'blink',
        'turn',
        'fallAsleep',
        'powerOff',
        'fetch', // Round 54
        'charge',
        // Round 52.
        'fromSky',
        'fromSide',
        'bugs',
        'notified',
        'flower',
        'butterfly',
        'ball',
        'shootingStar',
        'dance',
        // Round 53.
        'medicine',
        'eat',
        // Round 75: the weather's.
        'puddle',
        'twirl',
        'handOut',
        'flakes',
        'snowman',
        'snowball',
        'lost',
      ]);
    });

    /// Steps until he's up and about (an event, now and then, runs its
    /// course first: the random isn't seeded).
    void upAndAbout(PipBrain pip) {
      for (var i = 0;
          i < 60 * 60 &&
              pip.activity != PipActivity.standing &&
              pip.activity != PipActivity.walking;
          i++) {
        pip.step(1 / 60);
      }
    }

    test('play starts it, or says no', () {
      final egg = PipBrain(roomWidth: 120, hatched: false);
      expect(egg.play(PipAnimation.walk), isFalse);
      expect(egg.activity, PipActivity.egg);

      final pip = PipBrain(roomWidth: 120);
      expect(pip.play(PipAnimation.walk), isFalse, reason: 'coming up');
      for (var i = 0; i < 300; i++) {
        pip.step(1 / 60);
      }
      upAndAbout(pip);
      expect(pip.play(PipAnimation.spawn), isTrue);
      expect(pip.activity, PipActivity.spawning);
      for (var i = 0; i < 300; i++) {
        pip.step(1 / 60);
      }
      upAndAbout(pip);
      final facing = pip.facingRight;
      expect(pip.play(PipAnimation.turn), isTrue);
      expect(pip.facingRight, !facing);
      expect(pip.activity, PipActivity.standing);
      expect(pip.play(PipAnimation.hatch), isTrue);
      expect(pip.activity, PipActivity.hatching);
    });
  });
}
