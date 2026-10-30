import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_quest.dart';
import 'package:the_app/core/pip_quest_scene.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/widgets/pip_room.dart';

import '../helpers.dart';

/// His room at his quest's work (Round 127): it asks his life, he's at
/// it; plugged in, he doesn't go to his station meanwhile (spec 8).
void main() {
  Future<PipBrain> room(WidgetTester tester, FakePipLink link,
      {DateTime? at, bool animate = false}) async {
    final brain = PipBrain();
    final when = at ?? DateTime(2026, 11, 2, 10, 30);
    link.at = when;
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
              animate: animate,
              link: link,
              height: 140,
              scene: PipScene.at(PipPlace.home, when),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump();
    return brain;
  }

  final q = Quests.house;

  for (final (name, step) in [
    ('the house area', q.steps.indexWhere((s) => s.piece?.id == 'walls') + 3),
    (
      'the forest',
      q.steps.indexWhere(
          (s) => s.action == QuestAction.gather && s.place == QuestPlace.forest)
    ),
    ('the mine', q.steps.indexWhere((s) => s.action == QuestAction.gather)),
    (
      'the beach',
      q.steps.indexWhere(
          (s) => s.action == QuestAction.gather && s.place == QuestPlace.beach)
    ),
    ('the field', 0),
  ]) {
    testWidgets('at his work: drawn in $name', (tester) async {
      final link = FakePipLink()
        ..questing = (at: q.at(q.startOf(step) + 2), seconds: 150);
      final brain = await room(tester, link);
      expect(brain.activity, PipActivity.questing);
      expect(brain.questView, isNotNull);
      expect(tester.takeException(), isNull);
    });
  }

  testWidgets('plugged in at his work: no station (he\'s moving about)',
      (tester) async {
    final link = FakePipLink()
      ..plugged = true
      ..questing = (at: q.at(0), seconds: 100);
    final brain = await room(tester, link);
    expect(brain.activity, PipActivity.questing);
    expect(brain.station, isNull);
  });

  testWidgets('his work over (quest hours done): back on his field',
      (tester) async {
    final link = FakePipLink()..questing = (at: q.at(0), seconds: 100);
    final brain = await room(tester, link, animate: true);
    expect(brain.questView!.place, QuestScenePlace.field);
    link.questing = null;
    await tester.pump(const Duration(seconds: 2));
    expect(brain.activity, isNot(PipActivity.questing));
  });

  testWidgets(
      'opened again on him left mid-battery in quest hours: straight at his '
      'work (Round 129)', (tester) async {
    final brain = PipBrain(roomWidth: 160)..step(PipBrain.landEnd);
    expect(brain.takeBattery(120), isTrue);
    brain.step(0.3);
    expect(brain.activity, PipActivity.fetching);
    brain.leftAt = DateTime(2026, 11, 2, 10, 29);
    final link = FakePipLink()
      ..questing = (at: q.at(0), seconds: 100)
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
              animate: true,
              link: link,
              height: 140,
              scene: PipScene.at(PipPlace.home, link.at!),
            ),
          ),
        ),
      ),
    ));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(brain.activity, PipActivity.questing);
    expect(brain.battery, isNull);
  });
}
