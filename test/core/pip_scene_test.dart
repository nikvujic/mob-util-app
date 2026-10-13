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
    expect(room.props, {PipProp.sun}, reason: 'no clouds in the low strip');
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

  test('with the background off: no sky, nothing in it', () {
    final off = PipScene.at(PipPlace.home, at(23, 0), background: null);
    expect(off.sky, isNull);
    expect(off.props, isEmpty);
  });

  group('what he may start (the mayStart table)', () {
    test('nothing while in his egg, hatching or coming up', () {
      for (final doing in [
        PipActivity.egg,
        PipActivity.hatching,
        PipActivity.spawning,
      ]) {
        for (final a in PipAnimation.values) {
          expect(mayStart(doing, a), isFalse,
              reason: '${doing.name} ${a.name}');
        }
      }
    });

    test('anything while standing or walking', () {
      for (final doing in [PipActivity.standing, PipActivity.walking]) {
        for (final a in PipAnimation.values) {
          expect(mayStart(doing, a), isTrue, reason: '${doing.name} ${a.name}');
        }
      }
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
