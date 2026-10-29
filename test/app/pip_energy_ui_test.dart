import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/providers/pip_life_provider.dart';
import 'package:the_app/providers/pip_provider.dart';
import 'package:the_app/widgets/pip_energy_bar.dart';
import 'package:the_app/widgets/pip_portrait.dart';
import 'package:the_app/widgets/pip_room.dart';
import 'package:the_app/widgets/pip_sprites.dart';
import 'package:the_app/widgets/pixel_text.dart';

import '../helpers.dart';

/// Pip's energy, sleep and batteries on screen (Round 37).
void main() {
  late ProviderContainer container;
  PipBrain brain() => container.read(pipBrainProvider);
  PipLife life() => container.read(pipLifeProvider);

  /// The app at [now] with [pip], his life real (by that clock).
  Future<void> start(WidgetTester tester, DateTime now, PipLife pip) async {
    container =
        await pumpApp(tester, clock: () => now, pip: pip, realPipLink: true);
  }

  PipLife pipWith({
    double energy = 3,
    required DateTime at,
    int batteries = 0,
    DateTime? next,
    bool offSeen = false,
  }) =>
      PipLife(
        born: DateTime(2026, 10, 1),
        energy: energy,
        energyAt: at,
        batteries: batteries,
        nextBatteryAt: next ?? at.add(const Duration(hours: 5)),
        offSeen: offSeen,
      );

  group('batteries (Round 42)', () {
    test('are blue, unlike his energy', () {
      const blue = PipColours.batteryCharge;
      expect(blue.b, greaterThan(blue.r));
      expect(blue.b, greaterThan(blue.g));
      expect(PipSprites.colours['G'], blue, reason: 'the flying battery');
      expect(PipSprites.battery.join(), contains('G'));
      for (final n in [1, 2, 3]) {
        expect(PipEnergyBar.colourOf(n), isNot(blue));
      }
    });

    testWidgets('the one held beside his energy is blue', (tester) async {
      await tester.pumpWidget(const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
              child: PipEnergyBar(segments: 3, batteries: 2, pixel: 2))));
      expect(
          find.byType(CustomPaint),
          paints
            // (Compared as 32-bit colours: Paint keeps its own floats.)
            ..something((method, args) =>
                method == #drawRect &&
                (args[1] as Paint).color.toARGB32() ==
                    PipColours.batteryCharge.toARGB32()));
    });
  });

  group('his charging station (Round 44)', () {
    testWidgets(
        'opened while the phone charges: he\'s at his station, charging; '
        'Pip Home says so', (tester) async {
      final now = DateTime(2026, 10, 14, 12);
      container = await pumpApp(tester,
          clock: () => now,
          pip: pipWith(energy: 1.5, at: now, batteries: 1),
          realPipLink: true,
          power: FakePower(isPlugged: true));
      await openMenu(tester);
      await tester.pump();
      await tester.pump();
      expect(brain().station, isNotNull);
      expect(brain().activity, PipActivity.charging);
      // No battery while he's at it.
      expect(container.read(pipLifeProvider.notifier).refusalAt(now),
          PipRefusal.charging);
    });

    testWidgets('plugged in while watching: the station rises', (tester) async {
      final now = DateTime(2026, 10, 14, 12);
      final power = FakePower();
      container = await pumpApp(tester,
          clock: () => now,
          pip: pipWith(energy: 1.5, at: now),
          realPipLink: true,
          power: power);
      await openMenu(tester);
      await tester.pump(const Duration(seconds: 1));
      expect(brain().station, isNull);
      power.plug(true);
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 100));
      expect(brain().station, isNotNull);
    });
  });

  group('in the menu', () {
    testWidgets('his energy and batteries beside his name', (tester) async {
      final now = DateTime(2026, 10, 14, 12);
      await start(tester, now, pipWith(energy: 1.5, at: now, batteries: 2));
      await openMenu(tester);
      final bar =
          tester.widget<PipEnergyBar>(find.byKey(const Key('pipEnergy')));
      expect(bar.segments, 2);
      expect(bar.batteries, 2);
      expect(tester.getCenter(find.byKey(const Key('pipEnergy'))).dx,
          greaterThan(tester.getCenter(find.byKey(const Key('pipNameAge'))).dx),
          reason: 'on the right');
      expect(PipEnergyBar.colourOf(2), isNot(PipEnergyBar.colourOf(3)));
    });

    testWidgets('batteries due when the app opens are collected',
        (tester) async {
      final now = DateTime(2026, 10, 14, 12);
      await start(
          tester,
          now,
          pipWith(
              at: now,
              batteries: 1,
              next: now.subtract(const Duration(hours: 30))));
      await tester.pump();
      expect(life().batteries, 3,
          reason: 'piled up while away (Round 45), at most 3');
      expect(life().nextBatteryAt!.isAfter(now), isTrue);
    });

    testWidgets('ran out while away: he turns off (seen once), then is off',
        (tester) async {
      final now = DateTime(2026, 10, 14, 12);
      await start(tester, now,
          pipWith(energy: 0.5, at: now.subtract(const Duration(hours: 10))));
      await openMenu(tester);
      await tester.pump();
      expect(brain().activity, PipActivity.off);
      expect(life().offSeen, isTrue);
      expect(life().energy, 0);
    });

    testWidgets('off, a tap gives him a battery: he comes back on',
        (tester) async {
      final now = DateTime(2026, 10, 14, 12);
      await start(tester, now,
          pipWith(energy: 0, at: now, batteries: 1, offSeen: true));
      await openMenu(tester);
      await tester.pump();
      expect(brain().activity, PipActivity.off);
      await tester.tap(find.byType(PipRoom));
      await tester.pump();
      await tester.pump();
      expect(life().batteries, 0);
      expect(life().offSeen, isFalse);
      expect(brain().activity, isNot(PipActivity.off));
      expect(brain().tilt, 0);
    });

    testWidgets('full, a tap does nothing', (tester) async {
      final now = DateTime(2026, 10, 14, 12);
      await start(tester, now, pipWith(at: now, batteries: 2));
      await openMenu(tester);
      await tester.tap(find.byType(PipRoom));
      await tester.pump();
      expect(life().batteries, 2);
    });

    testWidgets('23:00 to 0:00: he falls asleep in front of you, once',
        (tester) async {
      final now = DateTime(2026, 10, 14, 23, 20);
      await start(tester, now, pipWith(at: now));
      await openMenu(tester);
      await tester.pump();
      expect(brain().activity, PipActivity.asleep);
      expect(life().sleepSeen, '2026-10-14');
      expect(
          container.read(pipLifeProvider.notifier).showAt(now), PipShow.asleep);
    });

    testWidgets('8:00 to 9:00: he wakes up in front of you', (tester) async {
      final now = DateTime(2026, 10, 15, 8, 15);
      await start(tester, now, pipWith(energy: 2.5, at: now));
      await openMenu(tester);
      await tester.pump();
      expect(brain().activity, isNot(PipActivity.asleep));
      expect(life().wakeSeen, '2026-10-15');
    });

    testWidgets('after 0:00 simply asleep; a tap gives no battery',
        (tester) async {
      final now = DateTime(2026, 10, 15, 2);
      await start(tester, now, pipWith(energy: 1.5, at: now, batteries: 1));
      await openMenu(tester);
      await tester.pump();
      expect(brain().activity, PipActivity.asleep);
      expect(life().sleepSeen, isNull, reason: 'no animation was played');
      await tester.tap(find.byType(PipRoom));
      await tester.pump();
      expect(life().batteries, 1);
    });

    testWidgets('a battery when tired: taken, a segment more', (tester) async {
      final now = DateTime(2026, 10, 14, 12);
      await start(tester, now, pipWith(energy: 1.5, at: now, batteries: 1));
      await openMenu(tester);
      await tester.pump();
      expect(brain().segments, 2);
      await tester.tap(find.byType(PipRoom));
      await tester.pump();
      await tester.pump();
      expect(life().batteries, 0);
      expect(PipEnergy.segments(life().energy), 3);
      expect(brain().segments, 3);
    });
  });

  group('Pip Home\'s status', () {
    Iterable<String> words() => find
        .byType(PixelText)
        .evaluate()
        .map((e) => (e.widget as PixelText).label);

    Future<void> openHome(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2340);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      await openTab(tester, 'Hub');
      await tester.tap(find.byTooltip('Pip'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));
    }

    testWidgets('energy, batteries, the next one, and what a tap does',
        (tester) async {
      final now = DateTime(2026, 10, 14, 12);
      await start(
          tester,
          now,
          pipWith(
              energy: 1.5,
              at: now,
              batteries: 2,
              next: now.add(const Duration(hours: 2, minutes: 15))));
      await openHome(tester);
      expect(
          tester
              .widget<PipEnergyBar>(find.byKey(const Key('pipStatusEnergy')))
              .segments,
          2);
      expect(words(), containsAll(['BATTERIES 2/3', 'NEXT IN 2H 15M']));
      expect(words(), isNot(contains('TAP THE FIELD TO GIVE HIM ONE')),
          reason: 'Round 116: no how-to');
    });

    testWidgets('Round 77: asleep (Round 116: no how-to wake him)',
        (tester) async {
      final now = DateTime(2026, 10, 15, 2);
      await start(
          tester,
          now,
          pipWith(energy: 2, at: now, batteries: 1)
              .copyWith(sleepSeen: () => '2026-10-14'));
      await openHome(tester);
      expect(words(), contains("HE'S ASLEEP"));
      expect(words(), isNot(contains('TAP HIM 3 TIMES TO WAKE HIM')));
      expect(tester.widget<PipPortrait>(find.byType(PipPortrait)).face,
          PipFace.asleep);
    });

    testWidgets('Round 77: woken this night already: asleep', (tester) async {
      final now = DateTime(2026, 10, 15, 2);
      await start(
          tester,
          now,
          pipWith(energy: 2, at: now, batteries: 1).copyWith(
              sleepSeen: () => '2026-10-14',
              wokenAt: () => DateTime(2026, 10, 15, 0, 30)));
      await openHome(tester);
      expect(words(), contains("HE'S ASLEEP"));
    });

    testWidgets('Round 77: woken: drowsy on his status', (tester) async {
      final now = DateTime(2026, 10, 15, 2);
      await start(
          tester,
          now,
          pipWith(energy: 3, at: now, batteries: 1).copyWith(
              sleepSeen: () => '2026-10-14',
              wokenAt: () => DateTime(2026, 10, 15, 1, 55)));
      await openHome(tester);
      expect(tester.widget<PipPortrait>(find.byType(PipPortrait)).face,
          PipFace.veryTired);
    });

    testWidgets('full: says so', (tester) async {
      final now = DateTime(2026, 10, 14, 12);
      await start(tester, now, pipWith(at: now, batteries: 1));
      await openHome(tester);
      expect(words(), contains("HE'S FULL"));
    });
  });
}
