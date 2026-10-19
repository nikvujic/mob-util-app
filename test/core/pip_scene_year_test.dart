import 'dart:math' as math;
import 'dart:ui' show Color;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/core/weather.dart';

/// His field through the year (Round 70): the seasons, the days it
/// dresses up for, and the weather (Internet Access's, or tried on in
/// Pip Home).
void main() {
  Set<PipProp> propsAt(DateTime now,
          {int? code, PipLook look = PipLook.none}) =>
      PipScene.at(PipPlace.room, now, weatherCode: code, look: look).props;

  test('the seasons by the month', () {
    expect([
      for (var m = 1; m <= 12; m++) Season.of(DateTime(2026, m, 15))
    ], [
      Season.winter, Season.winter, //
      Season.spring, Season.spring, Season.spring,
      Season.summer, Season.summer, Season.summer,
      Season.autumn, Season.autumn, Season.autumn,
      Season.winter,
    ]);
  });

  test(
      'its days: Halloween, Christmas (to the Orthodox one), New Year\'s '
      'Eve, Easter', () {
    PipOccasion? on(int y, int m, int d, [int h = 12]) =>
        PipOccasion.at(DateTime(y, m, d, h));
    expect(on(2026, 10, 23), isNull);
    expect(on(2026, 10, 24), PipOccasion.halloween);
    expect(on(2026, 10, 31), PipOccasion.halloween);
    expect(on(2026, 11, 1), isNull);
    expect(on(2026, 12, 19), isNull);
    expect(on(2026, 12, 20), PipOccasion.christmas);
    expect(on(2026, 12, 31, 19), PipOccasion.christmas);
    expect(on(2026, 12, 31, 20), PipOccasion.newYear);
    expect(on(2027, 1, 1, 1), PipOccasion.newYear);
    expect(on(2027, 1, 1, 2), PipOccasion.christmas);
    expect(on(2027, 1, 7), PipOccasion.christmas);
    expect(on(2027, 1, 8), isNull);
    // Orthodox Easter 2027: 2 May; Sunday and Monday.
    expect(on(2027, 5, 1), isNull);
    expect(on(2027, 5, 2), PipOccasion.easter);
    expect(on(2027, 5, 3), PipOccasion.easter);
    expect(on(2027, 5, 4), isNull);
  });

  test(
      'his field in each season: a tree; autumn\'s leaves, spring\'s '
      'petals', () {
    final spring = propsAt(DateTime(2026, 4, 10, 12));
    expect(spring, containsAll({PipProp.trees, PipProp.petals}));
    expect(spring, isNot(contains(PipProp.leaves)));
    expect(propsAt(DateTime(2026, 4, 10, 12), code: 61),
        isNot(contains(PipProp.petals)),
        reason: 'not in the rain');
    final summer = propsAt(DateTime(2026, 7, 10, 12));
    expect(summer.intersection({PipProp.petals, PipProp.leaves}), isEmpty);
    expect(summer, contains(PipProp.trees));
    expect(propsAt(DateTime(2026, 10, 10, 12)),
        containsAll({PipProp.trees, PipProp.leaves}));
    expect(propsAt(DateTime(2026, 2, 10, 12)), contains(PipProp.trees));
    expect(PipScene.at(PipPlace.room, DateTime(2026, 2, 10)).season,
        Season.winter);
  });

  test('its days\' things, and only on them', () {
    expect(propsAt(DateTime(2026, 10, 30, 23)),
        containsAll({PipProp.pumpkins, PipProp.bats}));
    expect(propsAt(DateTime(2026, 10, 30, 12)), contains(PipProp.pumpkins));
    expect(propsAt(DateTime(2026, 10, 30, 12)), isNot(contains(PipProp.bats)),
        reason: 'bats after dark');
    final christmas = propsAt(DateTime(2026, 12, 24, 12));
    expect(christmas, contains(PipProp.festiveTree));
    expect(christmas, isNot(contains(PipProp.trees)),
        reason: 'its pine instead');
    final eve = propsAt(DateTime(2026, 12, 31, 23));
    expect(eve, containsAll({PipProp.festiveTree, PipProp.fireworks}));
    expect(eve, isNot(contains(PipProp.trees)));
    expect(propsAt(DateTime(2027, 5, 2, 12)), contains(PipProp.eggs));
    final plain = propsAt(DateTime(2026, 7, 10, 23));
    expect(
        plain.intersection({
          PipProp.pumpkins,
          PipProp.bats,
          PipProp.festiveTree,
          PipProp.fireworks,
          PipProp.eggs,
        }),
        isEmpty);
  });

  test(
      'the weather: rain, snow, a storm, fog; a grey sky hides the sun, '
      'the moon and the stars, and has clouds even at night', () {
    final noon = DateTime(2026, 7, 10, 12);
    final night = DateTime(2026, 7, 10, 23);
    expect(PipScene.at(PipPlace.room, noon).weather, isNull,
        reason: 'none known: a plain sky');
    final rain = PipScene.at(PipPlace.room, noon, weatherCode: 63);
    expect(
        (rain.weather, rain.strength, rain.grey), (WeatherKind.rain, 2, true));
    expect(rain.props, contains(PipProp.rain));
    expect(rain.props, isNot(contains(PipProp.sun)));
    expect(propsAt(noon, code: 55), contains(PipProp.rain), reason: 'drizzle');
    expect(propsAt(noon, code: 75),
        containsAll({PipProp.snowfall, PipProp.clouds}));
    expect(
        PipScene.at(PipPlace.room, noon, weatherCode: 75).snowyGround, isTrue);
    expect(propsAt(noon, code: 95),
        containsAll({PipProp.rain, PipProp.lightning}));
    expect(propsAt(noon, code: 45), contains(PipProp.fog));
    final greyNight = propsAt(night, code: 3);
    expect(greyNight.intersection({PipProp.stars, PipProp.moon}), isEmpty);
    expect(greyNight, contains(PipProp.clouds));
    final clear = propsAt(noon, code: 0);
    expect(clear, contains(PipProp.sun));
    expect(clear.intersection({PipProp.rain, PipProp.snowfall, PipProp.fog}),
        isEmpty);
    expect(propsAt(night, code: 1), contains(PipProp.stars));
    expect(propsAt(noon, code: 2), contains(PipProp.sun),
        reason: 'partly cloudy: the sun still out');
    expect(PipScene.at(PipPlace.room, noon, weatherCode: 999).weather, isNull,
        reason: 'a code it doesn\'t know: a plain sky');
  });

  test('a grey sky is greyer; a storm\'s darker still', () {
    final noon = DateTime(2026, 7, 10, 12);
    final plain = PipScene.at(PipPlace.room, noon).skyStops!;
    final grey = PipScene.at(PipPlace.room, noon, weatherCode: 3).skyStops!;
    final storm = PipScene.at(PipPlace.room, noon, weatherCode: 95).skyStops!;
    double saturation(Color c) =>
        math.max(c.r, math.max(c.g, c.b)) - math.min(c.r, math.min(c.g, c.b));
    double light(Color c) => c.r + c.g + c.b;
    for (var i = 0; i < plain.length; i++) {
      expect(saturation(grey[i]), lessThan(saturation(plain[i])));
      expect(light(storm[i]), lessThan(light(grey[i])));
    }
    expect(PipScene.at(PipPlace.room, noon, weatherCode: 0).skyStops, plain);
  });

  test('Pip Home\'s try-ons: over what now is, one of each kind', () {
    final noon = DateTime(2026, 7, 10, 12);
    var look = PipLook.none
        .toggled(Season.winter)
        .toggled(WeatherKind.snow)
        .toggled(PipOccasion.christmas)
        .toggled(DayPart.night);
    final scene = PipScene.at(PipPlace.home, noon, look: look);
    expect((
      scene.season,
      scene.weather,
      scene.occasion,
      scene.part
    ), (
      Season.winter,
      WeatherKind.snow,
      PipOccasion.christmas,
      DayPart.night
    ));
    expect(scene.props, containsAll({PipProp.festiveTree, PipProp.snowfall}));
    look = look.toggled(WeatherKind.rain).toggled(Season.winter);
    expect((look.weather, look.season), (WeatherKind.rain, null),
        reason: 'another replaces it; the same again takes it off');
    expect(
        PipScene.at(PipPlace.home, noon, weatherCode: 75, look: look).weather,
        WeatherKind.rain,
        reason: 'over the real weather');
    // Something tried: the real day's things don't come along.
    expect(
        PipScene.at(PipPlace.home, DateTime(2026, 12, 24, 12),
                look: const PipLook(weather: WeatherKind.fog))
            .occasion,
        isNull);
    expect(
        look
            .toggled(DayPart.night)
            .toggled(PipOccasion.christmas)
            .toggled(WeatherKind.rain)
            .isNone,
        isTrue);
  });

  group('what he does in it', () {
    PipBrain standing({bool bleak = false, bool overcast = false}) {
      final b = PipBrain(roomWidth: 200, random: math.Random(3));
      b.step(PipBrain.landEnd);
      b.bleak = bleak;
      b.overcast = overcast;
      b.dark = true;
      return b;
    }

    Set<PipActivity> seen(PipBrain b) {
      final seen = <PipActivity>{};
      var stars = false;
      for (var i = 0; i < 60 * 60 * 20; i++) {
        b.step(1 / 60);
        seen.add(b.activity);
        stars = stars || b.shootingStar != null;
      }
      return {...seen, if (stars) PipActivity.stargazing};
    }

    test(
        'rain, snow or winter: no flowers or butterflies; a grey sky: no '
        'shooting stars', () {
      final fair = seen(standing());
      expect(fair.intersection({PipActivity.flower, PipActivity.butterfly}),
          isNotEmpty,
          reason: 'they do happen otherwise');
      expect(fair, contains(PipActivity.stargazing));
      final bleak = seen(standing(bleak: true, overcast: true));
      expect(bleak.intersection({PipActivity.flower, PipActivity.butterfly}),
          isEmpty);
      expect(bleak, isNot(contains(PipActivity.stargazing)));
      expect(bleak, contains(PipActivity.bugHunt), reason: 'bugs instead');
    });

    test('his field\'s clock always runs', () {
      final b = standing();
      final from = b.sceneClock;
      b.step(0.5);
      expect(b.sceneClock, closeTo(from + 0.5, 1e-9));
    });
  });
}
