import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/core/pip_quest.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/providers/pip_life_provider.dart';
import 'package:the_app/widgets/pip_house_picture.dart';
import 'package:the_app/widgets/pixel_text.dart';

import '../helpers.dart';

/// Pip Home's quests (Round 126, spec 3): the Quests row and card, Start
/// in quest hours, what he's on, the finished ones' pictures, and his
/// inventory between his info and his settings.
void main() {
  late ProviderContainer container;
  var now = DateTime(2026, 11, 2, 10, 30);

  Future<void> open(WidgetTester tester, {PipLife? pip}) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    container = await pumpApp(tester,
        clock: () => now,
        pip: pip ??
            PipLife(
              born: DateTime(2026, 10, 1),
              energy: PipEnergy.full,
              energyAt: now,
              nextBatteryAt: now.add(const Duration(hours: 3)),
            ));
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Pip'));
    await tester.pumpAndSettle();
  }

  Iterable<String> words() => [
        ...find
            .byType(PixelText)
            .evaluate()
            .map((e) => (e.widget as PixelText).label),
        ...find
            .byType(PixelParagraph)
            .evaluate()
            .map((e) => (e.widget as PixelParagraph).text),
      ];

  Future<void> tapKey(WidgetTester tester, String key) async {
    await tester.ensureVisible(find.byKey(Key(key)));
    await tester.tap(find.byKey(Key(key)));
    await tester.pumpAndSettle();
  }

  testWidgets(
      'the Quests row opens the card: the house offered; Start only in '
      'quest hours', (tester) async {
    now = DateTime(2026, 11, 2, 15);
    await open(tester);
    await tapKey(tester, 'pipQuests');
    expect(words(), contains('BUILD A HOUSE'));
    await tapKey(tester, 'pipStartQuest');
    expect(
        words(), contains('START BETWEEN 10:00 AND 11:30, OR 19:00 AND 20:30'));
    expect(container.read(pipLifeProvider).questId, isNull);
    await tapKey(tester, 'pipQuestInfo');
    expect(find.byKey(const Key('pipStatus')), findsOneWidget);
  });

  testWidgets(
      'started in quest hours: what he\'s on, how far, about when; it opens '
      'there while he works', (tester) async {
    now = DateTime(2026, 11, 2, 10, 30);
    await open(tester);
    // Not at work yet: his info first.
    expect(find.byKey(const Key('pipStatus')), findsOneWidget);
    await tapKey(tester, 'pipQuests');
    await tapKey(tester, 'pipStartQuest');
    final pip = container.read(pipLifeProvider);
    expect(pip.questId, 'house');
    expect(find.byKey(const Key('pipQuestBar')), findsOneWidget);
    expect(words(), contains('WALKING TO THE MINE'));
    expect(words().any((w) => w.startsWith('DONE ABOUT')), isTrue);
    expect(find.byKey(const Key('pipStartQuest')), findsNothing);
  });

  testWidgets('a quest under way: Pip Home opens on it in quest hours',
      (tester) async {
    now = DateTime(2026, 11, 3, 10, 40);
    await open(tester,
        pip: PipLife(
          born: DateTime(2026, 10, 1),
          energy: PipEnergy.full,
          energyAt: now,
          nextBatteryAt: now.add(const Duration(hours: 3)),
          questId: 'house',
          questFrom: DateTime(2026, 11, 2, 10),
          questMinutes: 400,
          questCountedTo: now,
        ));
    expect(find.byKey(const Key('pipQuest')), findsOneWidget);
    final at = Quests.house.at(400);
    expect(words(), contains(at.doing.toUpperCase()));
  });

  testWidgets(
      'his inventory, a swipe from his info: what he carries, with counts',
      (tester) async {
    // Partway: carrying what the script says.
    final q = Quests.house;
    var minutes = 0;
    for (var i = 0; i < q.steps.length; i++) {
      if (q.steps[i].action == QuestAction.walkBack) {
        minutes = q.startOf(i) + 1;
        break;
      }
    }
    now = DateTime(2026, 11, 3, 15);
    await open(tester,
        pip: PipLife(
          born: DateTime(2026, 10, 1),
          energy: PipEnergy.full,
          energyAt: now,
          nextBatteryAt: now.add(const Duration(hours: 3)),
          questId: 'house',
          questFrom: DateTime(2026, 11, 2, 10),
          questMinutes: minutes,
          questCountedTo: now,
        ));
    await tester.fling(
        find.byKey(const Key('pipCard')), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pipInventory')), findsOneWidget);
    final stone = q.at(minutes).inventory[QuestItem.stone]!;
    expect(stone, greaterThan(0));
    expect(find.bySemanticsLabel('Stone: $stone'), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('^Wood')), findsNothing);
  });

  testWidgets('nothing carried: says so', (tester) async {
    now = DateTime(2026, 11, 3, 15);
    await open(tester);
    await tester.fling(
        find.byKey(const Key('pipCard')), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
    expect(words(), contains('NOTHING YET'));
  });

  testWidgets('finished: its framed picture, its name, when', (tester) async {
    now = DateTime(2027, 1, 5, 15);
    await open(tester,
        pip: PipLife(
          born: DateTime(2026, 10, 1),
          energy: PipEnergy.full,
          energyAt: now,
          nextBatteryAt: now.add(const Duration(hours: 3)),
          questsDone: [PipQuestDone('house', DateTime(2027, 1, 2, 11))],
        ));
    await tapKey(tester, 'pipQuests');
    expect(find.byType(PipHousePicture), findsOneWidget);
    expect(words(), containsAll(['BUILD A HOUSE', '2.01.2027']));
    expect(words(), contains('NO QUESTS FOR NOW'));
  });
}
