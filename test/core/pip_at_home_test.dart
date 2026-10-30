import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_house.dart';
import 'package:the_app/core/pip_quest.dart';
import 'package:the_app/core/pip_quest_scene.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/core/weather.dart';
import 'package:the_app/widgets/pip_room.dart';

import '../helpers.dart';

/// His finished house as his home (Round 128, spec section 10): the
/// field's times, idling on its floor, its own events, his station and
/// his sleep in it, his field's things not.
void main() {
  DateTime at(int hour, [int minute = 0]) =>
      DateTime(2026, 11, 2, hour, minute);

  test('his field\'s times: 11:30–12:00 and 18:00–19:00', () {
    expect(PipQuest.fieldTimeAt(at(11, 29)), isFalse);
    expect(PipQuest.fieldTimeAt(at(11, 30)), isTrue);
    expect(PipQuest.fieldTimeAt(at(11, 59)), isTrue);
    expect(PipQuest.fieldTimeAt(at(12)), isFalse);
    expect(PipQuest.fieldTimeAt(at(17, 59)), isFalse);
    expect(PipQuest.fieldTimeAt(at(18)), isTrue);
    expect(PipQuest.fieldTimeAt(at(18, 59)), isTrue);
    expect(PipQuest.fieldTimeAt(at(19)), isFalse);
  });

  group('his brain', () {
    PipBrain home({int width = 160, int seed = 1}) {
      final brain = PipBrain(roomWidth: width, random: math.Random(seed))
        ..step(PipBrain.landEnd);
      brain.home(true);
      return brain;
    }

    double middle(PipBrain b) => b.x + PipBrain.width / 2;

    test('in: on his house\'s floor, between its walls, walking about', () {
      final brain = home();
      expect(brain.atHome, isTrue);
      expect(brain.homeView!.place, QuestScenePlace.house);
      expect(brain.homeView!.house.done, isTrue);
      for (var i = 0; i < 4000; i++) {
        brain.step(0.05);
        expect(brain.x, greaterThanOrEqualTo(PipBrain.homeLeft));
        expect(brain.x + PipBrain.width,
            lessThanOrEqualTo(PipBrain.homeRight + 0.001));
      }
    });

    test('out again: his field, all of it', () {
      final brain = home(width: 300);
      brain.home(false);
      expect(brain.atHome, isFalse);
      expect(brain.homeView, isNull);
      var furthest = 0.0;
      for (var i = 0; i < 6000; i++) {
        brain.step(0.05);
        if (brain.x > furthest) furthest = brain.x;
      }
      expect(furthest, greaterThan(PipBrain.homeRight));
    });

    test('in the middle of something, he goes once he\'s free', () {
      final brain = PipBrain(roomWidth: 160)..step(PipBrain.landEnd);
      brain.play(PipAnimation.bugs);
      expect(brain.activity, PipActivity.bugHunt);
      brain.home(true);
      expect(brain.atHome, isFalse);
      for (var i = 0; i < 400 && brain.activity == PipActivity.bugHunt; i++) {
        brain.step(0.05);
      }
      brain.home(true);
      expect(brain.atHome, isTrue);
    });

    test('his field\'s things don\'t happen in his house; the rest do', () {
      for (final a in PipAnimation.values) {
        final brain = home();
        final played = brain.play(a, demo: true);
        if (PipBrain.fieldOnly.contains(a)) {
          expect(played, isFalse, reason: '$a');
        }
      }
      expect(home().play(PipAnimation.dance), isTrue);
      expect(home().play(PipAnimation.fallAsleep), isTrue);
      expect(home().play(PipAnimation.notified), isTrue);
    });

    test(
        'on his own: a dance, a look out of a window, a warm by the fire; '
        'never his field\'s', () {
      final brain = home(seed: 7)..dark = true;
      final seen = <PipActivity>{};
      var atWindow = false, atFire = false;
      for (var i = 0; i < 40000; i++) {
        brain.step(0.05);
        seen.add(brain.activity);
        if (brain.activity == PipActivity.lookingUp) {
          final m = middle(brain);
          atWindow |= PipHouse.windows.any((w) => (m - w.$1 - 9).abs() < 1);
        }
        if (brain.activity == PipActivity.standing &&
            !brain.facingRight &&
            (brain.x - PipHouse.fireplaceRight - 2).abs() < 0.5) {
          atFire = true;
        }
      }
      expect(seen, contains(PipActivity.dancing));
      expect(atWindow, isTrue);
      expect(atFire, isTrue);
      for (final field in [
        PipActivity.bugHunt,
        PipActivity.flower,
        PipActivity.butterfly,
        PipActivity.ball,
        PipActivity.stargazing,
        PipActivity.weatherEvent,
      ]) {
        expect(seen, isNot(contains(field)), reason: '$field');
      }
    });

    test('rain or a storm in his house: no umbrella, tent or puddles', () {
      for (final w in [WeatherKind.rain, WeatherKind.storm]) {
        final brain = home()..weather = w;
        for (var i = 0; i < 200; i++) {
          brain.step(0.05);
        }
        expect(brain.umbrella, 0, reason: '$w');
        expect(brain.tent, isNull, reason: '$w');
        expect(brain.puddles, isEmpty, reason: '$w');
      }
    });

    test('coming in from the sky or the side: up through his floor', () {
      final brain = home();
      brain.enter(PipEntrance.sky);
      expect(brain.activity, PipActivity.spawning);
      brain.step(0.05);
      brain.enter(PipEntrance.side);
      expect(brain.activity, PipActivity.spawning);
    });

    test('his station comes up in his house, by its wall', () {
      final brain = home();
      brain.setPlugged(true, animate: false);
      final (sx, _, _) = brain.station!;
      expect(sx, greaterThanOrEqualTo(PipBrain.homeLeft));
      expect(sx + PipBrain.stationWidth, lessThanOrEqualTo(PipBrain.homeRight));
    });

    test('out on his adventure, at work: not in his house', () {
      final brain = home();
      brain.quest((at: Quests.house.at(0), seconds: 10));
      expect(brain.atHome, isFalse);
      expect(brain.homeView, isNull);
    });
  });

  group('his room', () {
    Future<PipBrain> room(WidgetTester tester, FakePipLink link) async {
      final brain = PipBrain();
      await tester.pumpWidget(Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 400,
              child: PipRoom(
                brain: brain,
                animate: false,
                link: link,
                height: 140,
                scene: PipScene.at(PipPlace.home, link.at!, weatherCode: 63),
              ),
            ),
          ),
        ),
      ));
      await tester.pump();
      await tester.pump();
      return brain;
    }

    testWidgets('his life says home: in his house, drawn', (tester) async {
      final link = FakePipLink()
        ..home = true
        ..at = at(15);
      final brain = await room(tester, link);
      expect(brain.atHome, isTrue);
      expect(tester.takeException(), isNull);
    });

    testWidgets('at work, his house waits', (tester) async {
      final link = FakePipLink()
        ..home = true
        ..questing = (at: Quests.house.at(0), seconds: 10)
        ..at = at(10, 30);
      final brain = await room(tester, link);
      expect(brain.atHome, isFalse);
      expect(brain.activity, PipActivity.questing);
    });

    testWidgets('not his home: his field', (tester) async {
      final link = FakePipLink()..at = at(15);
      final brain = await room(tester, link);
      expect(brain.atHome, isFalse);
    });
  });
}
