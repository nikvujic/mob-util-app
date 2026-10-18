import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:the_app/providers/pip_life_provider.dart';
import 'package:the_app/widgets/pixel_text.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_run.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/widgets/pip_room.dart';
import 'package:the_app/providers/pip_provider.dart';

import '../helpers.dart';

/// Pip's room at the bottom of the menu (Round 26).
void main() {
  final room = find.byKey(const Key('pipRoom'));

  testWidgets('in the menu, under the items, above the version',
      (tester) async {
    final container = await pumpApp(tester);
    await openMenu(tester);
    expect(room, findsOneWidget);
    expect(tester.getTopLeft(room).dy,
        greaterThan(tester.getBottomLeft(find.text('Settings')).dy));
    expect(
        tester.getBottomLeft(room).dy,
        lessThanOrEqualTo(
            tester.getTopLeft(find.textContaining('Version')).dy));
    // Not moving (here, in tests): simply standing there.
    expect(container.read(pipBrainProvider).spawned, isTrue);
  });

  testWidgets('his name line sits a pixel clear of his room (Round 41)',
      (tester) async {
    await pumpApp(tester);
    await openMenu(tester);
    final line = tester.getBottomLeft(find.byKey(const Key('pipNameAge'))).dy;
    final text = tester
        .getBottomLeft(find.descendant(
            of: find.byKey(const Key('pipNameAge')),
            matching: find.byType(PixelText)))
        .dy;
    final room = tester.getTopLeft(find.byType(PipRoom)).dy;
    expect(line, room);
    expect(room - text, greaterThanOrEqualTo(2));
  });

  testWidgets('his sky follows the clock (Round 35)', (tester) async {
    await pumpApp(tester, clock: () => DateTime(2026, 10, 13, 23));
    await openMenu(tester);
    final scene = tester.widget<PipRoom>(find.byType(PipRoom)).scene!;
    expect(scene.place, PipPlace.room);
    expect(scene.part, DayPart.night);
    expect(scene.props, {PipProp.stars, PipProp.moon});
    // Twice the first strip's 32 rows (Round 36): about 160 dp.
    expect(tester.getSize(find.byType(PipRoom)).height, greaterThan(140));
  });

  group('moving', () {
    late ProviderContainer container;
    PipBrain pip() => container.read(pipBrainProvider);

    Future<void> openMenuMoving(WidgetTester tester) async {
      await tester.tap(find.byTooltip('Menu').first);
      // Frames by hand: he never settles.
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    Future<void> closeMenu(WidgetTester tester) async {
      await tester.tapAt(const Offset(780, 300)); // beside the menu
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
    }

    testWidgets(
        'the first time the menu opens he comes out of the ground; the next '
        'time he is where he was', (tester) async {
      container = await pumpApp(tester, pipMoves: true);
      expect(pip().activity, PipActivity.spawning, reason: 'not yet seen');

      await openMenuMoving(tester);
      // Round 52: out of the ground, from the sky, or thrown in.
      const entrances = {
        PipActivity.spawning,
        PipActivity.falling,
        PipActivity.thrown,
      };
      expect(entrances, contains(pip().activity));
      expect(pip().roomWidth, greaterThan(PipBrain.width));
      for (var i = 0; i < 330; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(pip().spawned, isTrue);
      expect({...entrances, PipActivity.angry}, isNot(contains(pip().activity)),
          reason: 'in, after a few seconds');

      await closeMenu(tester);
      expect(room, findsNothing);
      final x = pip().x;
      await tester.pumpAndSettle(); // nothing moves while it's closed
      expect(pip().x, x);

      await openMenuMoving(tester);
      expect(entrances, isNot(contains(pip().activity)),
          reason: 'only the first time (or back after a while)');
    });

    testWidgets(
        'his ways in (Round 52): all three in the menu, a random one; back '
        'after a while he comes in again, not after a short while',
        (tester) async {
      final link = FakePipLink()..at = DateTime(2026, 10, 15, 12);
      container =
          await pumpApp(tester, pipMoves: true, pipLink: link, overrides: [
        pipBrainProvider.overrideWithValue(PipBrain(random: math.Random(1))),
      ]);
      await openMenuMoving(tester);
      expect(tester.widget<PipRoom>(find.byType(PipRoom)).entrances,
          PipEntrance.values.toSet());
      const entrances = {
        PipActivity.spawning,
        PipActivity.falling,
        PipActivity.thrown,
      };
      expect(entrances, contains(pip().activity));
      for (var i = 0; i < 330; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await closeMenu(tester);
      expect(pip().leftAt, link.at, reason: 'when he was left');

      // Five minutes away: just there.
      link.at = link.at!.add(const Duration(minutes: 5));
      await openMenuMoving(tester);
      expect(entrances, isNot(contains(pip().activity)));
      for (var i = 0; i < 330; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      await closeMenu(tester);

      // Away longer than [PipBrain.awayFor]: in again.
      link.at = link.at!.add(PipBrain.awayFor);
      await openMenuMoving(tester);
      expect(entrances, contains(pip().activity));
    });

    testWidgets('a notification comes: his screen shows one (Round 52)',
        (tester) async {
      final link = FakePipLink()..at = DateTime(2026, 10, 15, 12);
      container =
          await pumpApp(tester, pipMoves: true, pipLink: link, overrides: [
        pipBrainProvider.overrideWithValue(PipBrain(random: math.Random(2))),
      ]);
      await openMenuMoving(tester);
      for (var i = 0; i < 330; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(pip().screenShow, isNull);
      link.notifications.add(link.at!.add(const Duration(seconds: 1)));
      link.at = link.at!.add(const Duration(seconds: 2));
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(pip().screenShow?.$1.notification, isTrue);
    });

    testWidgets('a medicine due: he reminds of it (Round 53)', (tester) async {
      final link = FakePipLink()
        ..at = DateTime(2026, 10, 15, 12)
        ..medicineDue = true;
      container =
          await pumpApp(tester, pipMoves: true, pipLink: link, overrides: [
        pipBrainProvider.overrideWithValue(PipBrain(random: math.Random(2))),
      ]);
      await openMenuMoving(tester);
      var pill = false;
      for (var i = 0; i < 60 * 12 && !pill; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        pill = pip().screenShow?.$1 == PipScreen.pill;
      }
      expect(pill, isTrue);
    });

    testWidgets(
        'a recipe read within the hour: he eats, once for it; longer ago, '
        'not (Round 53)', (tester) async {
      final link = FakePipLink()
        ..at = DateTime(2026, 10, 15, 12)
        ..recipeReadAt = DateTime(2026, 10, 15, 11, 10);
      container =
          await pumpApp(tester, pipMoves: true, pipLink: link, overrides: [
        pipBrainProvider.overrideWithValue(PipBrain(random: math.Random(2))),
      ]);
      await openMenuMoving(tester);
      var ate = 0;
      var was = false;
      for (var i = 0; i < 60 * 30; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        final eating = pip().activity == PipActivity.eating;
        if (eating && !was) ate++;
        was = eating;
      }
      expect(ate, 1);
      // Another read, but 2 hours ago: not.
      link.recipeReadAt = DateTime(2026, 10, 15, 10);
      for (var i = 0; i < 60 * 5; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(pip().activity, isNot(PipActivity.eating));
      }
    });

    testWidgets('a ball kicked: the phone buzzes with it (Round 53)',
        (tester) async {
      final link = FakePipLink()..at = DateTime(2026, 10, 15, 12);
      container =
          await pumpApp(tester, pipMoves: true, pipLink: link, overrides: [
        pipBrainProvider.overrideWithValue(PipBrain(random: math.Random(7))),
      ]);
      await openMenuMoving(tester);
      for (var i = 0; i < 330; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      final buzzes = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          buzzes.add(call.arguments as String);
        }
        return null;
      });
      expect(pip().play(PipAnimation.ball), isTrue);
      for (var i = 0; i < 60 * 30 && pip().activity == PipActivity.ball; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(pip().activity, isNot(PipActivity.ball));
      expect(buzzes, [contains('medium')]);
    });

    testWidgets('the phone set to remove animations: he just stands',
        (tester) async {
      container = await pumpApp(tester, pipMoves: true);
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
          tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
      await openMenu(tester); // settles: nothing animates
      expect(pip().spawned, isTrue);
    });

    testWidgets(
        'out on his adventure (Round 63): opened, simply running; no '
        'station, taps do nothing; a level up seen flashes; at 18:00 he '
        'stops', (tester) async {
      final link = FakePipLink(batteries: 3)
        ..at = DateTime(2026, 10, 15, 13)
        ..out = (onBreak: false, breakDone: 0.0)
        ..plugged = true;
      container =
          await pumpApp(tester, pipMoves: true, pipLink: link, overrides: [
        pipBrainProvider.overrideWithValue(PipBrain(random: math.Random(1))),
      ]);
      await openMenuMoving(tester);
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(pip().activity, PipActivity.adventuring);
      expect(pip().run!.phase, RunPhase.running, reason: 'no setting off');
      expect(pip().station, isNull, reason: 'out, he doesn\'t charge');
      await tester.tap(find.byKey(const Key('pipRoom')));
      expect(link.batteries, 3, reason: 'taps do nothing');

      link.level = 2;
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(pip().levelFlash, isNotNull);

      link.out = null;
      for (var i = 0; i < 70; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(pip().run?.phase, RunPhase.ending, reason: 'seen: he slows');
      for (var i = 0; i < 120; i++) {
        await tester.pump(const Duration(milliseconds: 16));
      }
      expect(pip().activity, isNot(PipActivity.adventuring));
    });
  });

  group('his egg (Round 34)', () {
    testWidgets(
        'an egg until hatched; 7 taps, and he\'s out: his birthday, '
        'his page', (tester) async {
      final container = await pumpApp(tester,
          pipHatched: false, clock: () => DateTime(2026, 10, 14, 21, 30));
      await openMenu(tester);
      expect(container.read(pipBrainProvider).activity, PipActivity.egg);
      expect(find.byKey(const Key('pipNameAge')), findsNothing,
          reason: 'an egg has no name yet');
      final buzzes = <String>[];
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'HapticFeedback.vibrate') {
          buzzes.add(call.arguments as String);
        }
        return null;
      });
      for (var i = 0; i < 6; i++) {
        await tester.tap(room);
        await tester.pump();
      }
      expect(container.read(pipBrainProvider).crack, 3);
      expect(container.read(pipLifeProvider).hatched, isFalse);
      await tester.tap(room);
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(
          container.read(pipLifeProvider).born, DateTime(2026, 10, 14, 21, 30),
          reason: 'his birthday');
      expect(container.read(pipBrainProvider).spawned, isTrue);
      // His name and age above the room, now he's out.
      expect(tester.widget<PixelText>(find.byType(PixelText)).label,
          'Pip, 1 day old');
      expect(buzzes.where((b) => b.contains('light')), hasLength(6));
      expect(buzzes.where((b) => b.contains('heavy')), hasLength(1),
          reason: 'a longer one for the pop');
    });
  });

  group('his station charges him, watched (Round 58)', () {
    late ProviderContainer container;
    PipBrain pip() => container.read(pipBrainProvider);

    Future<void> frames(WidgetTester tester, double seconds) async {
      for (var t = 0.0; t < seconds; t += 0.1) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    Future<void> open(WidgetTester tester, FakePipLink link) async {
      container =
          await pumpApp(tester, pipMoves: true, pipLink: link, overrides: [
        pipBrainProvider.overrideWithValue(PipBrain(random: math.Random(3))),
      ]);
      await tester.tap(find.byTooltip('Menu').first);
      await frames(tester, 1);
    }

    testWidgets('at it: a segment every 30 seconds, up to full',
        (tester) async {
      final link = FakePipLink(segments: 1)
        ..at = DateTime(2026, 10, 15, 12)
        ..plugged = true;
      await open(tester, link);
      for (var i = 0; i < 200 && pip().activity != PipActivity.charging; i++) {
        await frames(tester, 0.1);
      }
      expect(pip().activity, PipActivity.charging);
      await frames(tester, PipBrain.chargeEvery - 1.5);
      expect(link.charges, 0, reason: 'not yet');
      await frames(tester, 2);
      expect(link.charges, 1);
      expect(pip().segments, 2, reason: 'his icon at once');
      await frames(tester, PipBrain.chargeEvery);
      expect(link.charges, 2);
      expect(pip().segments, 3);
      await frames(tester, PipBrain.chargeEvery);
      expect(link.charges, 2, reason: 'full');
    });

    testWidgets('not at it (unplugged): nothing', (tester) async {
      final link = FakePipLink(segments: 1)..at = DateTime(2026, 10, 15, 12);
      await open(tester, link);
      await frames(tester, PipBrain.chargeEvery + 2);
      expect(link.charges, 0);
    });

    testWidgets('off: the drone charges him, then he goes to plug in',
        (tester) async {
      final link = FakePipLink(show: PipShow.off, segments: 0)
        ..at = DateTime(2026, 10, 15, 12)
        ..plugged = true;
      await open(tester, link);
      expect(link.charges, 0);
      for (var i = 0; i < 100 && link.charges == 0; i++) {
        await frames(tester, 0.1);
      }
      expect(link.charges, 1);
      expect(pip().segments, 1);
      await frames(tester, 6);
      expect(
          {PipActivity.toStation, PipActivity.plugging, PipActivity.charging},
          contains(pip().activity));
    });
  });

  testWidgets("today's hat from his life (Round 61)", (tester) async {
    final link = FakePipLink()
      ..at = DateTime(2026, 10, 31, 12)
      ..hatToday = PipHat.witch;
    final container = await pumpApp(tester, pipLink: link);
    await openMenu(tester);
    await tester.pumpAndSettle();
    expect(container.read(pipBrainProvider).hat, PipHat.witch);
  });

  Iterable<String> labels() => find
      .byType(PixelText)
      .evaluate()
      .map((e) => (e.widget as PixelText).label);

  testWidgets(
      'out on his adventure, the menu shows his level, not his age '
      '(Round 63)', (tester) async {
    final out = PipLife(
      born: DateTime(2026, 10, 1),
      energyAt: DateTime(2026, 10, 15, 11),
      registeredAt: DateTime(2026, 10, 14, 14),
      xp: 720,
      outDay: '2026-10-15',
      outFrom: DateTime(2026, 10, 15, 12),
    );
    await pumpApp(tester, clock: () => DateTime(2026, 10, 15, 13), pip: out);
    await openMenu(tester);
    expect(labels(), contains('Pip, adventuring, level 2'));
  });

  testWidgets('back from it, his age again', (tester) async {
    final back = PipLife(
      born: DateTime(2026, 10, 1),
      energyAt: DateTime(2026, 10, 15, 11),
      registeredAt: DateTime(2026, 10, 14, 14),
      xp: 720,
      outDay: '2026-10-15',
      outFrom: DateTime(2026, 10, 15, 12),
    );
    await pumpApp(tester, clock: () => DateTime(2026, 10, 15, 19), pip: back);
    await openMenu(tester);
    expect(labels(), contains('Pip, 15 days old'));
  });
}
