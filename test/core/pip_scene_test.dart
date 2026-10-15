import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/core/theme.dart';

/// One system for what shows around Pip and what he may do (Round 35).
void main() {
  DateTime at(int h, int m) => DateTime(2026, 10, 13, h, m);

  test('the parts of the day', () {
    expect(dayPartAt(at(0, 0)), DayPart.night);
    expect(dayPartAt(at(5, 29)), DayPart.night);
    expect(dayPartAt(at(5, 30)), DayPart.dawn);
    expect(dayPartAt(at(6, 59)), DayPart.dawn);
    expect(dayPartAt(at(7, 0)), DayPart.day);
    expect(dayPartAt(at(18, 29)), DayPart.day);
    expect(dayPartAt(at(18, 30)), DayPart.dusk);
    expect(dayPartAt(at(19, 59)), DayPart.dusk);
    expect(dayPartAt(at(20, 0)), DayPart.night);
    expect(dayPartAt(at(23, 59)), DayPart.night);
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
    expect(room.props, {PipProp.sun, PipProp.clouds},
        reason: 'clouds since the room grew (Round 36)');
    expect(PipScene.at(PipPlace.home, at(12, 0)).props,
        {PipProp.sun, PipProp.clouds});
    expect(PipScene.at(PipPlace.room, at(23, 0)).props,
        {PipProp.stars, PipProp.moon});
    expect(PipScene.at(PipPlace.home, at(19, 0)).props,
        {PipProp.moon, PipProp.clouds});
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
        'charge',
        // Round 52.
        'fromSky',
        'fromSide',
        'bugs',
        'screen',
        'notified',
        'flower',
        'butterfly',
        'ball',
        'shootingStar',
        'dance',
      ]);
    });

    test('play starts it, or says no', () {
      final egg = PipBrain(roomWidth: 120, hatched: false);
      expect(egg.play(PipAnimation.walk), isFalse);
      expect(egg.activity, PipActivity.egg);

      final pip = PipBrain(roomWidth: 120);
      expect(pip.play(PipAnimation.walk), isFalse, reason: 'coming up');
      for (var i = 0; i < 300; i++) {
        pip.step(1 / 60);
      }
      expect(pip.play(PipAnimation.spawn), isTrue);
      expect(pip.activity, PipActivity.spawning);
      for (var i = 0; i < 300; i++) {
        pip.step(1 / 60);
      }
      final facing = pip.facingRight;
      expect(pip.play(PipAnimation.turn), isTrue);
      expect(pip.facingRight, !facing);
      expect(pip.activity, PipActivity.standing);
      expect(pip.play(PipAnimation.hatch), isTrue);
      expect(pip.activity, PipActivity.hatching);
    });
  });
}
