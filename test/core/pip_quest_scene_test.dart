import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_house.dart';
import 'package:the_app/core/pip_quest.dart';
import 'package:the_app/core/pip_quest_scene.dart';
import 'package:the_app/core/weather.dart';

/// What his quest's work looks like (Round 127): where he is and what
/// he's doing, from the step and the seconds into it.
void main() {
  final q = Quests.house;
  int first(bool Function(QuestStep) f) => q.steps.indexWhere(f);
  QuestView view(int step, double seconds) =>
      QuestView.of(q.at(q.startOf(step) + seconds ~/ 60), seconds);

  test('walking out: off the house area, along the field, into the place', () {
    final leaving = view(0, 5);
    expect(leaving.place, QuestScenePlace.house);
    expect(leaving.pose, QuestPose.walking);
    expect(leaving.offset, greaterThan(QuestView.home));
    expect(leaving.offset, lessThan(QuestView.edge));
    final field = view(0, 120);
    expect(field.place, QuestScenePlace.field);
    expect(field.scroll, greaterThan(0));
    final arriving = view(0, 5 * 60 - 3);
    expect(arriving.place, QuestScenePlace.mine);
    expect(arriving.pose, QuestPose.walking);
  });

  test(
      'walking home: out of the place, along the field (the other way), '
      'into the house area', () {
    final back = first((s) => s.action == QuestAction.walkBack);
    expect(view(back, 3).facingRight, isFalse);
    expect(
        view(back, 3).place,
        q.steps[back].place == QuestPlace.mine
            ? QuestScenePlace.mine
            : isNotNull);
    expect(view(back, 100).scroll, lessThan(0));
    expect(view(back, 5 * 60 - 2).place, QuestScenePlace.house);
  });

  test(
      'felling a tree: swing after swing; at the end it falls and its logs '
      'fly to him', () {
    final tree = first(
        (s) => s.action == QuestAction.gather && s.place == QuestPlace.forest);
    final early = view(tree, 30);
    expect(early.place, QuestScenePlace.forest);
    expect(early.swing, isNotNull);
    expect(early.fall, 0);
    final end = view(tree, Quests.treeMinutes * 60 - 1.0);
    expect(end.fall, greaterThan(0.5));
    expect(end.flyers.map((f) => f.item), everyElement('wood'));
    expect(end.flyers, isNotEmpty);
  });

  test('stone breaks off a boulder that wears down; sand is dug deeper', () {
    final stone = first((s) => s.action == QuestAction.gather);
    expect(view(stone, 60).rock, greaterThan(view(stone, 600).rock));
    final sand = first(
        (s) => s.action == QuestAction.gather && s.place == QuestPlace.beach);
    expect(view(sand, 400).dug, greaterThan(view(sand, 30).dug));
    expect(view(sand, 30).swing, isNull, reason: 'digging, no sword');
  });

  test(
      'building: walks over from the last piece (up the scaffold if it\'s '
      'higher), materials fly in, then works in puffs of dust', () {
    final second = first((s) => s.piece?.id == 'foundation') + 1;
    final start = view(second, 0.5);
    expect(start.place, QuestScenePlace.house);
    final work = view(second, 60);
    expect(work.pose, QuestPose.working);
    expect(
        work.puffs.isNotEmpty || view(second, 61.2).puffs.isNotEmpty, isTrue);
    final flying = view(second, start.pose == QuestPose.walking ? 4 : 1);
    expect(flying.flyers.map((f) => f.item), contains('stone'));
    final roof = first((s) => s.piece?.id == 'shingles') + 5;
    expect(view(roof, 300).lift, PipHouse.onScaffold);
    final floor = first((s) => s.piece?.id == 'walls');
    expect(view(floor, 300).lift, PipHouse.onFloor);
  });

  test('smelting: at the fireplace, facing it, the pane out at the end', () {
    final smelt = first((s) => s.action == QuestAction.smelt);
    final mid = view(smelt, 600);
    expect(mid.smelting, isTrue);
    expect(mid.facingRight, isFalse);
    final end = view(smelt, Quests.smeltMinutes * 60 - 1.0);
    expect(end.flyers.map((f) => f.item), contains('glass'));
  });

  test('done: standing by his house', () {
    final done = QuestView.of(q.at(q.totalMinutes), 0);
    expect(done.pose, QuestPose.standing);
    expect(done.house.done, isTrue);
  });

  group('his brain', () {
    test(
        'at his quest\'s work: questing, placed by it; then back to his '
        'field', () {
      final brain = PipBrain(roomWidth: 120);
      brain.quest((at: q.at(0), seconds: 100));
      expect(brain.activity, PipActivity.questing);
      expect(brain.questView!.place, QuestScenePlace.field);
      expect(brain.x + PipBrain.width / 2, closeTo(60, 0.01), reason: 'middle');
      brain.step(0.5);
      expect(brain.questView!.t, closeTo(100.5, 0.01));
      brain.quest(null);
      expect(brain.activity, PipActivity.standing);
    });

    test('the house area wider than the menu\'s room: it follows him', () {
      final brain = PipBrain(roomWidth: 120);
      final build = q.steps.indexWhere((s) => s.piece?.id == 'stairs');
      brain.quest((at: q.at(q.startOf(build) + 5), seconds: 300));
      expect(brain.questCamera, greaterThan(0));
      expect(brain.x, inInclusiveRange(0, 120 - PipBrain.width));
    });

    test('nothing else starts while he works: only sleep or running out', () {
      for (final next in PipAnimation.values) {
        expect(mayStart(PipActivity.questing, next),
            next == PipAnimation.fallAsleep || next == PipAnimation.powerOff,
            reason: '$next');
      }
    });

    test('swinging his sword at a tree', () {
      final brain = PipBrain(roomWidth: 160);
      final tree = q.steps.indexWhere((s) =>
          s.action == QuestAction.gather && s.place == QuestPlace.forest);
      brain.quest((at: q.at(q.startOf(tree) + 1), seconds: 61.2));
      expect(brain.sword, isNotNull);
    });

    for (final wet in [
      WeatherKind.drizzle,
      WeatherKind.rain,
      WeatherKind.snow,
      WeatherKind.storm,
    ]) {
      test('at his work in ${wet.label}: his rain hat, no umbrella or tent',
          () {
        final brain = PipBrain(roomWidth: 160)..weather = wet;
        brain.quest((at: q.at(0), seconds: 100));
        for (var i = 0; i < 40; i++) {
          brain.step(0.1);
        }
        expect(brain.activity, PipActivity.questing);
        expect(brain.hat, PipHat.rainHat);
        expect(brain.umbrella, 0);
        expect(brain.tent, isNull);
      });
    }

    test('the weather changing at his work: not looked up at after', () {
      final brain = PipBrain(roomWidth: 160)..weather = WeatherKind.cloudy;
      brain.step(0.1);
      brain.quest((at: q.at(0), seconds: 100));
      brain.weather = WeatherKind.rain;
      brain.step(0.1);
      brain.quest(null);
      brain.step(0.1);
      expect(brain.activity, isNot(PipActivity.lookingUp));
    });

    test('dry, or off his work: not his rain hat', () {
      final brain = PipBrain(roomWidth: 160)..weather = WeatherKind.cloudy;
      brain.quest((at: q.at(0), seconds: 100));
      expect(brain.hat, isNot(PipHat.rainHat));
      brain.weather = WeatherKind.rain;
      brain.quest(null);
      expect(brain.hat, isNot(PipHat.rainHat));
    });
  });
}
