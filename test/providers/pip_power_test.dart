import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/power.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/pip_life_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';

import '../helpers.dart';

/// Whether the phone is plugged in (Round 44: Pip's charging station).
void main() {
  var now = DateTime(2026, 10, 14, 10);

  ProviderContainer start(FakePower power, {bool wasPlugged = false}) {
    final container = ProviderContainer(overrides: [
      appStorageProvider.overrideWithValue(AppStorage.inMemory(
        initialPip: PipLife(
          born: DateTime(2026, 10, 1),
          energy: 1.5, // not full (full, he'd drop to just below)
          energyAt: now,
          batteries: 1,
          nextBatteryAt: now.add(const Duration(hours: 5)),
        ),
        initialPreferences: Preferences(pipPlugged: wasPlugged),
      )),
      clockProvider.overrideWithValue(() => now),
      powerSourceProvider.overrideWithValue(power),
    ]);
    addTearDown(container.dispose);
    return container;
  }

  setUp(() => now = DateTime(2026, 10, 14, 10));

  test(
      'plugged in (Round 45): he uses energy as ever, and can\'t run out; '
      'his icon shows what he has (Round 58)', () async {
    final power = FakePower(isPlugged: true);
    final container = start(power);
    final link = container.read(pipLinkProvider);
    expect(link.plugged, isFalse, reason: 'not asked yet');
    await pumpEventQueue();
    expect(link.plugged, isTrue);
    expect(container.read(preferencesProvider).pipPlugged, isTrue,
        reason: 'kept for after a restart');
    final pip = container.read(pipLifeProvider.notifier);
    now = now.add(const Duration(hours: 2));
    expect(pip.levelAt(now), closeTo(1.0, 0.001), reason: 'used as ever');
    expect(pip.segmentsAt(now), 1,
        reason: 'Round 58: not kept as when plugged in');
    now = now.add(const Duration(hours: 20));
    expect(pip.levelAt(now), PipEnergy.chargingFloor, reason: 'never out');
    expect(pip.showAt(now), isNot(PipShow.powerOff));

    power.plug(false);
    await pumpEventQueue();
    expect(link.plugged, isFalse);
    expect(container.read(preferencesProvider).pipPlugged, isFalse);
    expect(pip.segmentsAt(now), 1);
  });

  test('asked again while he\'s looked at, every few seconds at most',
      () async {
    final power = FakePower();
    final container = start(power);
    final link = container.read(pipLinkProvider);
    link.look();
    await pumpEventQueue();
    expect(link.plugged, isFalse);
    // Plugged in while the app was away (no event heard).
    power.isPlugged = true;
    link.look();
    await pumpEventQueue();
    expect(link.plugged, isFalse, reason: 'not asked again so soon');
    await Future<void>.delayed(PipPowerNotifier.askEvery);
    link.look();
    await pumpEventQueue();
    expect(link.plugged, isTrue);
  });

  test('after a restart, plugged in when last seen: time away counts',
      () async {
    final power = FakePower(isPlugged: true);
    final container = start(power, wasPlugged: true);
    container.read(pipLinkProvider).look();
    final pip = container.read(pipLifeProvider.notifier);
    expect(pip.charging, isTrue, reason: 'straight away');
    now = now.add(const Duration(hours: 2));
    await pumpEventQueue();
    // Round 58: what he has, however long ago he was plugged in (it used
    // to keep what he had then: full for days).
    expect(pip.segmentsAt(now), 1);
    expect(pip.levelAt(now), closeTo(1.0, 0.001));
  });

  test('plugged in, no battery taken: "he\'s charging"', () async {
    final power = FakePower(isPlugged: true);
    final container = start(power);
    container.read(pipLinkProvider).look();
    await pumpEventQueue();
    final pip = container.read(pipLifeProvider.notifier);
    expect(pip.refusalAt(now), PipRefusal.charging);
    expect(container.read(pipLinkProvider).giveBattery(), isFalse);
    expect(container.read(pipLifeProvider).batteries, 1);
    // Unplugged, he can have it.
    power.plug(false);
    await pumpEventQueue();
    expect(pip.refusalAt(now), isNull);
    expect(PipEnergy.segments(pip.levelAt(now)), 2);
  });
}
