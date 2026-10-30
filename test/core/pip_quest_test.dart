import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_quest.dart';

/// Pip's quests (Round 125, `docs/QUESTS_SPEC.md`): quest hours, the
/// house's script, and where it is after some work minutes.
void main() {
  DateTime at(int h, [int m = 0, int day = 2]) => DateTime(2026, 11, day, h, m);

  group('quest hours', () {
    test('10:00–11:30 and 19:00–20:30, the ends as a day ends', () {
      for (final (t, inside) in [
        (at(9, 59), false),
        (at(10), true),
        (at(11, 29), true),
        (at(11, 30), false),
        (at(15), false),
        (at(19), true),
        (at(20, 29), true),
        (at(20, 30), false),
      ]) {
        expect(PipQuest.inHoursAt(t), inside, reason: '$t');
        expect(PipQuest.canStartAt(t), inside, reason: '$t');
      }
    });

    test('the windows between two moments, cut to them; none backwards', () {
      final spans = PipQuest.windowsBetween(at(11), at(10, 15, 3));
      expect(spans, [
        (at(11), at(11, 30)),
        (at(19), at(20, 30)),
        (at(10, 0, 3), at(10, 15, 3)),
      ]);
      expect(PipQuest.windowsBetween(at(12), at(11)), isEmpty);
      final total = PipQuest.windowsBetween(at(0, 0, 1), at(0, 0, 11))
          .fold(0, (sum, s) => sum + s.$2.difference(s.$1).inMinutes);
      expect(total, 10 * PipQuest.minutesPerDay);
    });

    test('when the work left is done, if no hours are lost', () {
      expect(PipQuest.finishAt(at(11), 30), at(11, 30));
      expect(PipQuest.finishAt(at(11), 31), at(19, 1));
      expect(PipQuest.finishAt(at(21), 10), at(10, 10, 3));
      expect(PipQuest.finishAt(at(8), 180 * 2), at(20, 30, 3));
    });
  });

  group('the house', () {
    final q = Quests.house;

    test('about two months of work (55–65 days of quest hours)', () {
      final days = q.totalMinutes / PipQuest.minutesPerDay;
      expect(days, inInclusiveRange(55, 65));
    });

    test(
        'never builds without the materials, never carries more than a load '
        'home, every piece built, its count, in order', () {
      final inv = {for (final i in QuestItem.values) i: 0};
      var load = 0;
      final order = <String>[];
      final counts = <String, int>{};
      for (final s in q.steps) {
        s.takes.forEach((k, v) => inv[k] = inv[k]! - v);
        expect(inv.values.every((v) => v >= 0), isTrue,
            reason: 'short at ${s.action} ${s.piece?.id}');
        s.gives.forEach((k, v) => inv[k] = inv[k]! + v);
        switch (s.action) {
          case QuestAction.walkOut:
            load = 0;
          case QuestAction.gather:
            load += s.gives.values.single;
            final item = s.gives.keys.single;
            expect(load, lessThanOrEqualTo(Quests.carry[item]!));
          case QuestAction.build:
            final id = s.piece!.id;
            if (order.isEmpty || order.last != id) order.add(id);
            counts[id] = (counts[id] ?? 0) + 1;
          case QuestAction.walkBack || QuestAction.smelt:
        }
      }
      expect(order, [for (final p in Quests.housePieces) p.id],
          reason: 'each piece once, in the order given');
      for (final p in Quests.housePieces) {
        expect(counts[p.id], p.count, reason: p.id);
      }
    });

    test('a trip: out, gathering at one place, back', () {
      for (var i = 0; i < q.steps.length; i++) {
        final s = q.steps[i];
        if (s.action != QuestAction.gather) continue;
        var j = i;
        while (q.steps[j].action == QuestAction.gather) {
          expect(q.steps[j].place, s.place);
          j--;
        }
        expect(q.steps[j].action, QuestAction.walkOut);
        expect(q.steps[j].place, s.place);
      }
    });

    test('glass is smelted before the windows, from sand and wood', () {
      final firstWindow = q.steps.indexWhere((s) => s.piece?.id == 'windows');
      final smelts = [
        for (final (i, s) in q.steps.indexed)
          if (s.action == QuestAction.smelt) i,
      ];
      expect(smelts.length, q.needs[QuestItem.glass]);
      expect(smelts.first, lessThan(firstWindow));
      expect(q.gathers[QuestItem.sand], 2 * q.needs[QuestItem.glass]!);
    });

    test('where it is: the start, a step begun (its materials in it), done',
        () {
      final start = q.at(0);
      expect((start.step, start.into, start.done), (0, 0, false));
      expect(start.current.action, QuestAction.walkOut);
      expect(start.inventory.values.every((v) => v == 0), isTrue);
      expect(start.doing, 'Walking to the mine');

      final firstBuild =
          q.steps.indexWhere((s) => s.action == QuestAction.build);
      final before = q.at(q.startOf(firstBuild) - 1);
      final begun = q.at(q.startOf(firstBuild) + 3);
      expect(begun.step, firstBuild);
      expect(begun.into, 3);
      expect(begun.inventory[QuestItem.stone],
          before.inventory[QuestItem.stone]! - 2);
      expect(begun.doing, 'Laying the foundation: 1 of 30');
      expect(begun.built['foundation'], isNull);
      expect(q.at(q.startOf(firstBuild + 1)).built['foundation'], 1);

      final done = q.at(q.totalMinutes + 500);
      expect(done.done, isTrue);
      expect(done.fraction, 1);
      expect(done.doing, 'Done');
      for (final p in Quests.housePieces) {
        expect(done.built[p.id], p.count);
      }
      expect(done.inventory.values.every((v) => v >= 0), isTrue);
    });

    test('progress only goes forward', () {
      var last = -1.0;
      for (var m = 0; m <= q.totalMinutes; m += 37) {
        final f = q.at(m).fraction;
        expect(f, greaterThanOrEqualTo(last));
        last = f;
      }
    });

    test('what he\'s on, for the card', () {
      final gather = q.steps.indexWhere((s) =>
          s.action == QuestAction.gather && s.place == QuestPlace.forest);
      expect(q.at(q.startOf(gather)).doing, startsWith('Chopping wood: 0 of '));
      final smelt = q.steps.indexWhere((s) => s.action == QuestAction.smelt);
      expect(q.at(q.startOf(smelt)).doing, 'Making glass: 1 of 9');
      final back = q.steps.indexWhere((s) => s.action == QuestAction.walkBack);
      expect(q.at(q.startOf(back)).doing, 'Walking home');
    });

    test('the chain: the house first, then nothing yet', () {
      expect(Quests.nextAfter(const []), q);
      expect(Quests.nextAfter(const ['house']), isNull);
      expect(Quests.byId('house'), q);
      expect(Quests.byId('nope'), isNull);
    });
  });
}
