import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/core/pip_quest.dart';
import 'package:the_app/core/pip_quest_scene.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/widgets/pip_room.dart';

import '../helpers.dart';

/// Round 134: no cuts between his places while he's watched: run out at
/// his work he falls there and gets up there; his work over, he walks
/// back onto his field; into and out of his house through its door.
void main() {
  final q = Quests.house;

  PipBrain up({int width = 160}) =>
      PipBrain(roomWidth: width, random: math.Random(3))
        ..step(PipBrain.landEnd);

  void run(PipBrain brain, double seconds) {
    for (var t = 0.0; t < seconds; t += 0.05) {
      brain.step(0.05);
    }
  }

  test(
      'run out at his work (up the scaffold): falls there, lies there, a '
      'battery gets him up there, at it again', () {
    final brain = up();
    final high = q.steps.indexWhere((s) => s.piece?.id == 'rafters');
    final now = (at: q.at(q.startOf(high) + 2), seconds: 150.0);
    brain.quest(now);
    final x = brain.x, lift = brain.lift;
    expect(lift, greaterThan(20), reason: 'up the scaffold');
    brain.quest(null, down: true);
    expect(brain.show(PipShow.powerOff), isTrue);
    expect(brain.activity, PipActivity.poweringOff);
    expect(brain.questView!.place, QuestScenePlace.house);
    expect(brain.downAtWork, isTrue);
    run(brain, 4);
    expect(brain.activity, PipActivity.off);
    expect(brain.x, closeTo(x, 0.01), reason: 'where he fell');
    expect(brain.lift, closeTo(lift, 0.01));
    expect(brain.questView!.place, QuestScenePlace.house);
    expect(brain.takeBattery(x + 30), isTrue);
    expect(brain.activity, PipActivity.poweringOn);
    run(brain, PipBrain.onEnd + 0.1);
    expect(brain.activity, PipActivity.questing);
    expect(brain.questView!.place, QuestScenePlace.house);
    expect(brain.downAtWork, isFalse);
  });

  test('opened on him off at his work (not seen falling): lying there', () {
    final brain = up();
    final mine = q.steps.indexWhere((s) => s.action == QuestAction.gather);
    brain.quest((at: q.at(q.startOf(mine) + 1), seconds: 100));
    brain.quest(null, down: true);
    expect(brain.show(PipShow.off), isTrue);
    expect(brain.activity, PipActivity.off);
    expect(brain.questView!.place, QuestScenePlace.mine);
  });

  /// Round 141: his work over, seen, at [place]: he walks off it (its
  /// left edge, the way home) first, still there, never cut away.
  void walksOff(PipBrain brain, QuestScenePlace place) {
    expect(brain.activity, PipActivity.questing, reason: 'still there');
    var last = brain.questView!.pipCentre(160);
    for (var i = 0; i < 2000 && brain.activity == PipActivity.questing; i++) {
      final view = brain.questView!;
      expect(view.place, place, reason: 'walking off it, not cut away');
      final centre = view.pipCentre(160);
      expect(centre, lessThanOrEqualTo(last + 0.01));
      last = centre;
      brain.step(0.05);
      brain.quest(null, animate: true, toHome: brain.atHome);
    }
    expect(last, lessThan(0), reason: 'off its left edge');
  }

  test(
      'his work over, seen: off the mine, then back in from his field\'s '
      'right edge', () {
    final brain = up();
    final mine = q.steps.indexWhere((s) => s.action == QuestAction.gather);
    brain.quest((at: q.at(q.startOf(mine) + 1), seconds: 100));
    brain.quest(null, animate: true);
    walksOff(brain, QuestScenePlace.mine);
    expect(brain.activity, PipActivity.walking);
    expect(brain.questView, isNull);
    expect(brain.x, greaterThan(160 - PipBrain.width), reason: 'off the edge');
    expect(brain.facingRight, isFalse);
    var last = brain.x;
    for (var i = 0; i < 200 && brain.activity == PipActivity.walking; i++) {
      brain.step(0.05);
      expect(brain.x, lessThanOrEqualTo(last));
      last = brain.x;
    }
    expect(brain.activity, PipActivity.standing);
    expect(brain.x + PipBrain.width, lessThanOrEqualTo(160));

    final unseen = up();
    unseen.quest((at: q.at(q.startOf(mine) + 1), seconds: 100));
    unseen.quest(null);
    expect(unseen.activity, PipActivity.standing);
    expect(unseen.x + PipBrain.width, lessThanOrEqualTo(160));
  });

  test(
      'his work over with his house next (20:30, it built), seen: in at '
      'its door, not onto his field and round again (Round 136)', () {
    final brain = up();
    final mine = q.steps.indexWhere((s) => s.action == QuestAction.gather);
    brain.quest((at: q.at(q.startOf(mine) + 1), seconds: 100));
    brain.quest(null, animate: true, toHome: true);
    expect(brain.atHome, isFalse, reason: 'off the mine first');
    var i = 0;
    for (; i < 2000 && brain.activity == PipActivity.questing; i++) {
      brain.step(0.05);
      brain.quest(null, animate: true, toHome: true);
    }
    expect(brain.atHome, isTrue);
    expect(brain.activity, PipActivity.walking);
    expect(brain.x, closeTo(PipBrain.homeRight - PipBrain.width, 2));
    expect(brain.facingRight, isFalse);
    // Asked again (his room, a second later): already home, nothing more.
    brain.home(true, animate: true);
    expect(brain.atHome, isTrue);
    expect(brain.activity, PipActivity.walking);
  });

  test(
      'into his house, seen: off his field first, then in at his door; out '
      'again: to his door, then in from his field\'s edge', () {
    final brain = up();
    brain.home(true, animate: true);
    expect(brain.atHome, isFalse);
    expect(brain.activity, PipActivity.walking);
    for (var i = 0; i < 600 && !brain.atHome; i++) {
      brain.step(0.05);
      brain.home(true, animate: true);
    }
    expect(brain.atHome, isTrue);
    expect(brain.x, closeTo(PipBrain.homeRight - PipBrain.width, 1),
        reason: 'in at his door');
    expect(brain.activity, PipActivity.walking);
    run(brain, 10);
    brain.home(false, animate: true);
    expect(brain.atHome, isTrue, reason: 'to his door first');
    for (var i = 0; i < 600 && brain.atHome; i++) {
      brain.step(0.05);
      brain.home(false, animate: true);
    }
    expect(brain.atHome, isFalse);
    expect(brain.x, greaterThan(160 - PipBrain.width), reason: 'at the edge');
    expect(brain.activity, PipActivity.walking);
  });

  test('opened again mid-walk between his places: done by now', () {
    final brain = up();
    brain.home(true, animate: true);
    brain.step(0.5);
    brain.freshScenes();
    expect(brain.atHome, isTrue);
    expect(brain.x, inInclusiveRange(PipBrain.homeLeft, PipBrain.homeRight));
    final back = up();
    final mine = q.steps.indexWhere((s) => s.action == QuestAction.gather);
    back.quest((at: q.at(q.startOf(mine) + 1), seconds: 100));
    back.quest(null, animate: true);
    run(back, 1);
    expect(back.activity, PipActivity.questing, reason: 'walking off it');
    back.freshScenes();
    expect(back.activity, PipActivity.standing);
    expect(back.x + PipBrain.width, lessThanOrEqualTo(160));
  });

  test(
      'Round 141: off at the mine, a battery, his work over by then: he '
      'gets up there and walks off it, not cut to his field', () {
    final brain = up();
    final mine = q.steps.indexWhere((s) => s.action == QuestAction.gather);
    brain.quest((at: q.at(q.startOf(mine) + 1), seconds: 100));
    brain.quest(null, down: true);
    brain.show(PipShow.off);
    expect(brain.takeBattery(brain.x + 30), isTrue);
    run(brain, PipBrain.onEnd + 0.1);
    expect(brain.questView!.place, QuestScenePlace.mine);
    brain.quest(null, animate: true);
    walksOff(brain, QuestScenePlace.mine);
    expect(brain.activity, PipActivity.walking);
    expect(brain.x, greaterThan(160 - PipBrain.width),
        reason: 'in from the '
            'edge');
  });

  test('Round 141: his work over at the house area, seen: down, and off it',
      () {
    final brain = up();
    final high = q.steps.indexWhere((s) => s.piece?.id == 'rafters');
    brain.quest((at: q.at(q.startOf(high) + 2), seconds: 150.0));
    expect(brain.lift, greaterThan(20));
    brain.quest(null, animate: true);
    var lift = brain.lift;
    var i = 0;
    for (; i < 2000 && brain.activity == PipActivity.questing; i++) {
      expect(brain.questView!.place, QuestScenePlace.house);
      expect(brain.lift, lessThanOrEqualTo(math.max(lift, 1) + 0.01),
          reason: 'down (a step\'s bob aside)');
      lift = brain.lift;
      brain.step(0.05);
      brain.quest(null, animate: true);
    }
    expect(i, greaterThan(20), reason: 'a walk, not a cut');
    expect(brain.activity, PipActivity.walking);
  });

  testWidgets(
      'run out at his work, plugged in: his station doesn\'t come up there',
      (tester) async {
    final brain = up();
    final mine = q.steps.indexWhere((s) => s.action == QuestAction.gather);
    brain.quest((at: q.at(q.startOf(mine) + 1), seconds: 100));
    final link = FakePipLink(show: PipShow.off)
      ..plugged = true
      ..at = DateTime(2026, 11, 2, 10, 30);
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
              scene: PipScene.at(PipPlace.home, link.at!),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    expect(brain.activity, PipActivity.off);
    expect(brain.downAtWork, isTrue);
    expect(brain.station, isNull);
  });
}
