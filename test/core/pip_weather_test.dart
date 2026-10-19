import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_run.dart';
import 'package:the_app/core/pip_weather.dart';
import 'package:the_app/core/weather.dart';

/// Round 75: the weather in his field: his tent in a storm (over
/// everything else he might be doing), his umbrella in the rain, the
/// weather's events, and the weather out on his adventure.
void main() {
  PipBrain up({int seed = 1, WeatherKind? weather}) {
    final b = PipBrain(roomWidth: 200, random: math.Random(seed));
    b.weather = weather; // known from the start: simply there
    b.step(PipBrain.landEnd);
    for (var i = 0; i < 600 && b.activity != PipActivity.standing; i++) {
      b.step(1 / 60);
    }
    return b;
  }

  void steps(PipBrain b, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      b.step(1 / 60);
    }
  }

  group('the rules', () {
    test('what each weather puts over him, and his pace', () {
      expect(coverFor(WeatherKind.storm), PipCover.tent);
      expect(coverFor(WeatherKind.rain), PipCover.umbrella);
      for (final w in [
        null,
        WeatherKind.clear,
        WeatherKind.drizzle,
        WeatherKind.snow,
        WeatherKind.fog,
      ]) {
        expect(coverFor(w), PipCover.none, reason: '$w');
      }
      expect(paceIn(WeatherKind.fog), lessThan(0.6));
      expect(paceIn(WeatherKind.rain), 1);
    });

    test('each event happens in its own weather, none in a storm', () {
      for (final e in PipWeatherEvent.values) {
        expect(weatherEventsIn(weatherFor(e)), contains(e), reason: e.name);
      }
      expect(weatherEventsIn(WeatherKind.storm), isEmpty);
      expect(weatherEventsIn(WeatherKind.clear), isEmpty);
      expect(weatherEventsIn(null), isEmpty);
      expect(weatherEventsIn(null, snowy: true),
          containsAll([PipWeatherEvent.snowman, PipWeatherEvent.snowball]),
          reason: 'a ski day\'s snow');
    });

    test('in his tent he keeps still: only sleep or running out start', () {
      for (final a in PipAnimation.values) {
        expect(mayStart(PipActivity.sheltering, a),
            a == PipAnimation.fallAsleep || a == PipAnimation.powerOff,
            reason: a.name);
      }
      for (final a in PipAnimation.values) {
        expect(mayStart(PipActivity.weatherEvent, a), isFalse);
        expect(mayStart(PipActivity.lookingUp, a), isFalse);
      }
      // The weather's start only while he's up and about.
      expect(mayStart(PipActivity.standing, PipAnimation.snowman), isTrue);
      expect(mayStart(PipActivity.asleep, PipAnimation.puddle), isFalse);
    });

    test('the tent goes up, stays, comes down (from as far as it got)', () {
      final tent = PipTent(10);
      expect(tent.up, 0);
      expect(tent.hides, isFalse);
      tent.step(PipTent.pitchTime / 2);
      expect(tent.up, closeTo(0.5, 0.01));
      tent.pack();
      expect(tent.up, closeTo(0.5, 0.01), reason: 'down from there');
      tent.step(PipTent.packTime * 0.25);
      expect(tent.up, closeTo(0.25, 0.01));
      tent.repitch();
      expect(tent.up, closeTo(0.25, 0.01), reason: 'back up from there');
      tent.step(PipTent.pitchTime);
      expect(tent.phase, TentPhase.up);
      expect(tent.hides, isTrue);
      tent.pack();
      tent.step(PipTent.packTime + 0.01);
      expect(tent.gone, isTrue);
    });

    test('his umbrella opens and shuts over half a second', () {
      final u = PipUmbrella();
      u.step(0.25, wanted: true);
      expect(u.open, closeTo(0.5, 1e-9));
      u.step(1, wanted: true);
      expect(u.open, 1);
      u.step(0.5, wanted: false);
      expect(u.shown, isFalse);
    });
  });

  group('a storm', () {
    test(
        'up and about: his tent goes up round him; inside he keeps still, '
        'nothing happens; over, it comes down and he\'s about again', () {
      final b = up();
      b.weather = WeatherKind.storm;
      b.step(1 / 60);
      expect(b.activity, PipActivity.sheltering);
      expect(b.tent, isNotNull);
      expect(b.inTent, isFalse, reason: 'still going up');
      steps(b, PipTent.pitchTime);
      expect(b.inTent, isTrue);
      final x = b.x;
      for (var i = 0; i < 60 * 60; i++) {
        b.step(1 / 60);
        expect(b.activity, PipActivity.sheltering, reason: 'no events');
      }
      expect(b.x, x, reason: 'not a step');
      expect(b.play(PipAnimation.walk), isFalse);
      expect(b.play(PipAnimation.dance), isFalse);
      b.weather = WeatherKind.rain;
      b.step(1 / 60);
      expect(b.tent!.phase, TentPhase.packing);
      steps(b, PipTent.packTime + 0.1);
      expect(b.tent, isNull);
      expect(b.activity, isNot(PipActivity.sheltering));
    });

    test('a battery flies into his tent (one at a time)', () {
      final b = up(weather: WeatherKind.storm);
      steps(b, PipTent.pitchTime + 0.1);
      expect(b.canTakeBattery, isTrue);
      b.takeBuzzes();
      expect(b.takeBattery(20), isTrue);
      expect(b.canTakeBattery, isFalse, reason: 'one at a time');
      final (from, _) = b.battery!;
      steps(b, 0.35);
      final (mid, _) = b.battery!;
      final door = b.tent!.left + PipTent.width / 2;
      expect((mid - door).abs(), lessThan((from - door).abs()));
      steps(b, 0.5);
      expect(b.battery, isNull);
      expect(b.takeBuzzes(), contains(PipBuzz.light));
      expect(b.activity, PipActivity.sheltering, reason: 'still inside');
    });

    test(
        'asleep: the tent goes up over him; woken in the storm, he stays in '
        'it', () {
      final b = up();
      expect(b.play(PipAnimation.fallAsleep), isTrue);
      steps(b, 5);
      expect(b.activity, PipActivity.asleep);
      b.weather = WeatherKind.storm;
      steps(b, PipTent.pitchTime + 0.1);
      expect(b.activity, PipActivity.asleep, reason: 'sleeping on');
      expect(b.inTent, isTrue);
      expect(b.play(PipAnimation.wakeUp), isTrue);
      steps(b, 6);
      expect(b.activity, PipActivity.sheltering);
      expect(b.inTent, isTrue);
    });

    test('off: the tent over him; back on in it, inside', () {
      final b = up();
      b.play(PipAnimation.powerOff);
      steps(b, 4);
      expect(b.activity, PipActivity.off);
      b.weather = WeatherKind.storm;
      steps(b, PipTent.pitchTime + 0.1);
      expect(b.inTent, isTrue);
      expect(b.takeBattery(30), isTrue);
      steps(b, 5);
      expect(b.activity, PipActivity.sheltering);
    });

    test('in the middle of something (a dance): the tent once it\'s done', () {
      final b = up();
      expect(b.play(PipAnimation.dance), isTrue);
      b.weather = WeatherKind.storm;
      b.step(1 / 60);
      expect(b.tent, isNull, reason: 'it runs its course');
      expect(b.activity, PipActivity.dancing);
      steps(b, 6);
      expect(b.tent, isNotNull);
      expect(b.activity, PipActivity.sheltering);
    });

    test('asleep in his tent at night: up in it, the storm over, out', () {
      final b = up(weather: WeatherKind.storm);
      steps(b, 2);
      expect(b.play(PipAnimation.fallAsleep), isTrue);
      steps(b, 5);
      expect(b.activity, PipActivity.asleep);
      expect(b.inTent, isTrue);
      b.weather = WeatherKind.cloudy;
      steps(b, PipTent.packTime + 0.1);
      expect(b.tent, isNull, reason: 'down over him as he sleeps');
      expect(b.activity, PipActivity.asleep);
    });
  });

  group('rain', () {
    test(
        'his umbrella opens while he\'s about; shut asleep, or for something '
        'that takes his hands (bugs)', () {
      final b = up(weather: WeatherKind.rain);
      steps(b, 1);
      expect(b.umbrella, 1);
      expect(b.play(PipAnimation.bugs), isTrue);
      steps(b, 0.6);
      expect(b.umbrella, 0);
      steps(b, 20);
      final asleep = up(weather: WeatherKind.rain);
      asleep.play(PipAnimation.fallAsleep);
      steps(asleep, 3);
      expect(asleep.umbrella, 0);
      final dry = up(weather: WeatherKind.clear);
      steps(dry, 1);
      expect(dry.umbrella, 0);
    });

    test('puddles in the rain; he jumps in the nearest: a splash', () {
      final b = up(weather: WeatherKind.rain);
      expect(b.puddles, hasLength(3));
      expect(up(weather: WeatherKind.clear).puddles, isEmpty);
      b.x = 10;
      expect(b.play(PipAnimation.puddle), isTrue);
      var jumped = false;
      var splashed = false;
      for (var i = 0;
          i < 60 * 10 && b.activity == PipActivity.weatherEvent;
          i++) {
        b.step(1 / 60);
        jumped = jumped || b.lift > 4;
        splashed = splashed || b.splash != null;
      }
      expect(jumped, isTrue);
      expect(splashed, isTrue);
      expect(b.x + PipBrain.width / 2, closeTo(b.puddles.first, 1),
          reason: 'in the nearest');
    });

    test('a twirl under his umbrella', () {
      final b = up(weather: WeatherKind.rain);
      steps(b, 1);
      expect(b.play(PipAnimation.twirl), isTrue);
      steps(b, 1);
      expect(b.umbrella, 1, reason: 'open through it');
      expect(b.umbrellaTurn, isNot(0));
    });
  });

  group('the weather\'s events', () {
    test('drizzle: a hand out, a drop landing on it', () {
      final b = up(weather: WeatherKind.drizzle);
      expect(b.play(PipAnimation.handOut), isTrue);
      expect(b.weatherHand, isNotNull);
      var dropped = false;
      for (var i = 0; i < 60 * 4; i++) {
        b.step(1 / 60);
        dropped = dropped || b.dropOnHand != null;
      }
      expect(dropped, isTrue);
      expect(b.activity, isNot(PipActivity.weatherEvent));
    });

    test('snow: flakes on his tongue (mouth open, hops)', () {
      final b = up(weather: WeatherKind.snow);
      expect(b.play(PipAnimation.flakes), isTrue);
      expect(b.frame, PipFrame.oh);
      var hopped = false;
      for (var i = 0; i < 60 * 4; i++) {
        b.step(1 / 60);
        hopped = hopped || b.lift > 1;
      }
      expect(hopped, isTrue);
    });

    test(
        'snow: a snowman built beside him, stage by stage; it stays while '
        'the snow does, then melts away', () {
      final b = up(weather: WeatherKind.snow);
      expect(b.play(PipAnimation.snowman), isTrue);
      final man = b.snowman!;
      final built = <double>[];
      for (var i = 0; i < 60 * 10; i++) {
        b.step(1 / 60);
        built.add(man.built);
      }
      expect(built.first, lessThan(0.1));
      expect(built.last, 1);
      expect(
          man.left + PipSnowman.width <= b.x ||
              man.left >= b.x + PipBrain.width,
          isTrue,
          reason: 'beside him');
      steps(b, 60);
      expect(b.snowman, same(man), reason: 'it stays');
      b.weather = WeatherKind.cloudy;
      steps(b, PipSnowman.meltTime / 2);
      expect(man.melted, closeTo(0.5, 0.05));
      steps(b, PipSnowman.meltTime);
      expect(b.snowman, isNull);
    });

    test('snow: a snowball at you, splatted on the glass, gone after', () {
      final b = up(weather: WeatherKind.snow);
      expect(b.play(PipAnimation.snowball), isTrue);
      var held = false;
      for (var i = 0; i < 60 * 1.5; i++) {
        b.step(1 / 60);
        held = held || b.holdingSnowball;
      }
      expect(held, isTrue);
      final splat = b.splat!;
      expect(splat.y, lessThan(b.skyRows + 1));
      steps(b, PipSplat.flyTime + PipSplat.stayTime + 0.2);
      expect(b.splat, isNull);
    });

    test('fog: slower; lost (a question mark, this way and that), then off',
        () {
      final clear = up(weather: WeatherKind.clear);
      final fog = up(weather: WeatherKind.fog);
      expect(fog.pace, closeTo(clear.pace * paceIn(WeatherKind.fog), 1e-9));
      expect(fog.play(PipAnimation.lost), isTrue);
      expect(fog.lost, isTrue);
      final ways = <bool>{};
      for (var i = 0; i < 60 * 3.2; i++) {
        fog.step(1 / 60);
        if (fog.lost) ways.add(fog.facingRight);
      }
      expect(ways, {true, false});
      expect(fog.activity, PipActivity.walking);
    });

    test(
        'in their weather, free moments go mostly to its events (one '
        'snowman at a time); in clear weather none', () {
      for (final (weather, expected) in [
        (WeatherKind.snow, true),
        (WeatherKind.clear, false),
      ]) {
        final b = PipBrain(roomWidth: 200, random: math.Random(4))
          ..weather = weather;
        b.step(PipBrain.landEnd);
        final seen = <PipWeatherEvent>{};
        var snowmen = 0;
        for (var i = 0; i < 60 * 60 * 20; i++) {
          final before = b.snowman;
          b.step(1 / 60);
          if (b.weatherEvent case final e?) seen.add(e);
          if (b.snowman != null && !identical(b.snowman, before)) snowmen++;
        }
        expect(seen.isNotEmpty, expected, reason: '$weather');
        if (expected) {
          expect(seen, containsAll(weatherEventsIn(weather)));
          expect(snowmen, 1, reason: 'one at a time');
        }
      }
    });
  });

  test(
      'the weather changing: it comes in over a few seconds, and he looks '
      'up (the first, simply there)', () {
    final b = up(weather: WeatherKind.clear);
    expect(b.weatherIn, 1);
    b.weather = WeatherKind.snow;
    expect(b.weatherIn, 0);
    b.step(1 / 60);
    expect(b.activity, PipActivity.lookingUp);
    expect(b.frame, PipFrame.oh);
    steps(b, comeIn / 2);
    expect(b.weatherIn, closeTo(0.5, 0.02));
    steps(b, comeIn);
    expect(b.weatherIn, 1);
    expect(b.activity, isNot(PipActivity.lookingUp));
    // Asleep, not woken by it.
    final asleep = up(weather: WeatherKind.clear);
    asleep.play(PipAnimation.fallAsleep);
    steps(asleep, 3);
    asleep.weather = WeatherKind.fog;
    steps(asleep, 1);
    expect(asleep.activity, PipActivity.asleep);
  });

  group('out on his adventure', () {
    const out = (onBreak: false, breakDone: 0.0);

    PipBrain running({WeatherKind? weather}) {
      final b = PipBrain(roomWidth: 200, random: math.Random(1));
      b.step(PipBrain.landEnd);
      b.adventure(out, animate: false);
      b.weather = weather;
      return b;
    }

    test(
        'a storm on when he\'d set off: he stays in his tent at home, and '
        'goes once it\'s over', () {
      final b = up(weather: WeatherKind.storm);
      steps(b, 1);
      b.adventure(out, animate: true);
      steps(b, 1);
      expect(b.activity, PipActivity.sheltering);
      b.weather = WeatherKind.cloudy;
      for (var i = 0; i < 60 * 3; i++) {
        b.step(1 / 60);
        b.adventure(out, animate: true);
      }
      expect(b.activity, PipActivity.adventuring);
    });

    test(
        'a storm: he stops, his tent by the path, he waits it out inside '
        '(no bugs); over, it comes down and he draws his sword and runs on',
        () {
      final b = running();
      b.run!.bugComing(hits: false);
      b.weather = WeatherKind.storm;
      steps(b, PipRun.shelterSlow + 0.1);
      expect(b.run!.phase, RunPhase.sheltering);
      expect(b.run!.speed, 0);
      expect(b.sword, isNull, reason: 'put away');
      steps(b, PipTent.pitchTime);
      expect(b.inTent, isTrue);
      expect(b.tent, same(b.run!.tent));
      for (var i = 0; i < 60 * 20; i++) {
        b.step(1 / 60);
        if (b.bug case (_, _, final fleeing)) {
          expect(fleeing, isTrue, reason: 'only the one running off');
        }
      }
      expect(b.fighting, isFalse, reason: 'no XP held in it');
      b.weather = WeatherKind.rain;
      steps(b, PipTent.packTime + 0.1);
      expect(b.run!.tent, isNull);
      steps(b, PipRun.drawTime + 0.1);
      expect(b.run!.phase, RunPhase.running);
      expect(b.sword, isNotNull);
    });

    test('18:00 in his tent: it comes down and he\'s back', () {
      final b = running(weather: WeatherKind.storm);
      steps(b, PipRun.shelterSlow + PipTent.pitchTime + 0.2);
      expect(b.run!.phase, RunPhase.sheltering);
      b.adventure(null, animate: true);
      steps(b, PipTent.packTime + 0.2);
      expect(b.activity, isNot(PipActivity.adventuring));
    });

    test('snow: snowmen among the bugs (two strikes)', () {
      final b = running(weather: WeatherKind.snow);
      final seen = <PipFoe>{};
      for (var i = 0; i < 60 * 60 * 3; i++) {
        b.step(1 / 60);
        if (b.bug != null) seen.add(b.run!.foe);
      }
      expect(seen, contains(PipFoe.snowman));
      expect(PipFoe.snowman.hits, 2);
      final dry = running(weather: WeatherKind.clear);
      for (var i = 0; i < 60 * 60 * 3; i++) {
        dry.step(1 / 60);
        if (dry.bug != null) expect(dry.run!.foe, isNot(PipFoe.snowman));
      }
    });

    test('fog: he runs slower', () {
      final b = running(weather: WeatherKind.fog);
      steps(b, 1);
      expect(b.run!.speed,
          closeTo(PipRun.runSpeed * paceIn(WeatherKind.fog), 1e-9));
      expect(running(weather: WeatherKind.rain).run!.pace, 1);
    });

    test('skiing in a storm: no tent (the hut\'s his shelter)', () {
      final b = PipBrain(roomWidth: 200, random: math.Random(1))..skiing = true;
      b.step(PipBrain.landEnd);
      b.adventure(out, animate: false);
      b.weather = WeatherKind.storm;
      steps(b, 3);
      expect(b.run!.phase, isNot(RunPhase.sheltering));
      expect(b.tent, isNull);
    });
  });
}
