import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/providers/pip_provider.dart';

import '../helpers.dart';

/// Round 77: three taps on him asleep wake him (if his life lets it).
void main() {
  final room = find.byKey(const Key('pipRoom'));
  late ProviderContainer container;
  PipBrain pip() => container.read(pipBrainProvider);

  Future<void> frames(WidgetTester tester, double seconds) async {
    for (var t = 0.0; t < seconds; t += 0.1) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<FakePipLink> open(WidgetTester tester, {bool wakeable = true}) async {
    final link = FakePipLink(show: PipShow.asleep, batteries: 2)
      ..at = DateTime(2026, 10, 19, 2)
      ..wakeable = wakeable;
    container =
        await pumpApp(tester, pipMoves: true, pipLink: link, overrides: [
      pipBrainProvider.overrideWithValue(PipBrain(random: math.Random(3))),
    ]);
    await tester.tap(find.byTooltip('Menu').first);
    await frames(tester, 1);
    expect(pip().activity, PipActivity.asleep);
    return link;
  }

  testWidgets(
      'three taps: woken, one eye open first, then up (drowsy); a battery '
      'then', (tester) async {
    final link = await open(tester);
    await tester.tap(room);
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(room);
    await tester.pump(const Duration(milliseconds: 100));
    expect(link.wakes, 0, reason: 'two: not yet');
    expect(pip().activity, PipActivity.asleep);
    await tester.tap(room);
    await tester.pump(const Duration(milliseconds: 100));
    expect(link.wakes, 1);
    expect(pip().activity, PipActivity.stirring);
    await frames(tester, PipBrain.stirEnd + PipBrain.wakeHopEnd + 0.5);
    expect(pip().drowsy, isTrue);
    expect(pip().face, PipFace.veryTired);
    expect(
        {PipActivity.standing, PipActivity.walking}, contains(pip().activity));
    // Up: a tap gives him a battery.
    await tester.tap(room);
    await frames(tester, 0.3);
    expect(link.batteries, 1);
  });

  testWidgets('taps too far apart: not woken', (tester) async {
    final link = await open(tester);
    for (var i = 0; i < 4; i++) {
      link.at = link.at!.add(PipEnergy.wakeTapGap * 1.5);
      await tester.tap(room);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(link.wakes, 0);
    expect(pip().activity, PipActivity.asleep);
  });

  testWidgets('his life says no (woken this night already): asleep still',
      (tester) async {
    final link = await open(tester, wakeable: false);
    for (var i = 0; i < 3; i++) {
      await tester.tap(room);
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(link.wakes, 0);
    await frames(tester, 1);
    expect(pip().activity, PipActivity.asleep);
    expect(link.batteries, 2, reason: 'no battery asleep');
  });

  testWidgets('his 15 minutes over: he falls asleep again', (tester) async {
    final link = await open(tester);
    for (var i = 0; i < 3; i++) {
      await tester.tap(room);
      await tester.pump(const Duration(milliseconds: 100));
    }
    await frames(tester, PipBrain.stirEnd + PipBrain.wakeHopEnd + 0.5);
    link
      ..show = PipShow.asleep
      ..drowsy = false;
    // Looked at again (each second).
    await frames(tester, 1.5);
    expect({PipActivity.fallingAsleep, PipActivity.asleep},
        contains(pip().activity));
    await frames(tester, PipBrain.asleepEnd + 0.5);
    expect(pip().activity, PipActivity.asleep);
  });
}
