import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/providers/pip_life_provider.dart';

/// Round 58: off with the phone plugged in, the station's drone charges
/// him a segment; his station's segments reach his life.
void main() {
  PipBrain up({int seed = 3}) => PipBrain(
        roomWidth: 140,
        random: math.Random(seed),
      )
        ..skyRows = 59
        ..step(PipBrain.landEnd);

  void run(PipBrain pip, double seconds) {
    for (var t = 0.0; t < seconds; t += 1 / 60) {
      pip.step(1 / 60);
    }
  }

  /// Off, the phone plugged in: the station simply there.
  PipBrain offPlugged() {
    final p = up()
      ..segments = 0
      ..show(PipShow.off);
    expect(p.activity, PipActivity.off);
    p.setPlugged(true, animate: false);
    expect(p.station, isNotNull);
    return p;
  }

  group('the drone', () {
    test(
        'up out of the station, over to him, beams; then he comes on, it '
        'goes home, and he walks over to plug in', () {
      final p = offPlugged();
      expect(p.droneDue, isTrue);
      expect(p.drone, isNull, reason: 'not yet stepped');
      run(p, 0.1);
      final (sx, _, _) = p.station!;
      final (x0, y0, beam0) = p.drone!;
      expect(beam0, isFalse);
      expect(
          x0,
          closeTo(
              sx + (PipBrain.stationWidth - PipBrain.droneWidth) / 2, 0.01));
      expect(y0, greaterThanOrEqualTo(PipBrain.stationHeight - 5.0),
          reason: 'coming out of its top');
      run(p, PipBrain.droneRise + PipBrain.droneOut);
      final (x1, y1, beam1) = p.drone!;
      expect(beam1, isTrue);
      expect(y1, closeTo(PipBrain.droneHover, 1.1));
      // Over him: where he lies, his middle.
      final middle = p.x + PipBrain.width + PipBrain.height / 2;
      final left = p.x - PipBrain.height / 2;
      expect(
          (x1 + PipBrain.droneWidth / 2 - middle).abs() < 1 ||
              (x1 + PipBrain.droneWidth / 2 - left).abs() < 1,
          isTrue);
      expect(p.activity, PipActivity.off, reason: 'still charging him');
      expect(p.takeDroneCharge(), isFalse);
      run(p, PipBrain.droneBeam);
      expect(p.activity, PipActivity.poweringOn);
      expect(p.battery, isNull, reason: 'no battery flies in');
      expect(p.takeDroneCharge(), isTrue);
      expect(p.takeDroneCharge(), isFalse, reason: 'once');
      expect(p.drone!.$3, isFalse, reason: 'going home');
      p.segments = 1;
      run(p, PipBrain.droneBack + PipBrain.droneSink + 0.1);
      expect(p.drone, isNull, reason: 'back in the station');
      run(p, PipBrain.onEnd);
      expect(
          {PipActivity.toStation, PipActivity.plugging, PipActivity.charging},
          contains(p.activity));
      expect(p.droneDue, isFalse);
    });

    test('not plugged in, or a demo of running out: none', () {
      final p = up()
        ..segments = 0
        ..show(PipShow.off);
      run(p, 1);
      expect(p.drone, isNull);
      expect(p.droneDue, isFalse);
      final demo = up()..play(PipAnimation.powerOff, demo: true);
      demo.setPlugged(true, animate: false);
      run(demo, PipBrain.offEnd + 0.5);
      expect(demo.activity, PipActivity.off);
      expect(demo.drone, isNull);
    });

    test('the station rising: it waits till it is up', () {
      final p = up()
        ..segments = 0
        ..show(PipShow.off)
        ..setPlugged(true);
      expect(p.droneDue, isFalse);
      run(p, 0.2);
      expect(p.drone, isNull);
      run(p, PipBrain.stationRise);
      expect(p.drone, isNotNull);
    });

    test('a battery given meanwhile: it goes home, nothing charged', () {
      final p = offPlugged();
      run(p, PipBrain.droneRise + 0.3);
      expect(p.takeBattery(10), isTrue);
      run(p, 1 / 60);
      expect(p.drone!.$3, isFalse);
      run(p, PipBrain.droneBack + PipBrain.droneSink + 0.2);
      expect(p.drone, isNull);
      expect(p.takeDroneCharge(), isFalse);
    });

    test('unplugged: the station sinks, the drone with it', () {
      final p = offPlugged();
      run(p, PipBrain.droneRise + 0.3);
      p.setPlugged(false);
      run(p, 1 / 60);
      expect(p.drone, isNull);
      expect(p.takeDroneCharge(), isFalse);
    });

    test('his room not moving: simply done, him back on', () {
      final p = offPlugged();
      expect(p.sendDrone(animate: false), isTrue);
      expect(p.activity, PipActivity.poweringOn);
      expect(p.takeDroneCharge(), isTrue);
      expect(p.drone, isNull);
      expect(p.sendDrone(animate: false), isFalse, reason: 'on again');
    });
  });

  group('his life (Round 58)', () {
    final now = DateTime(2026, 10, 15, 12);
    PipLifeNotifier start(PipLife pip) => PipLifeNotifier(
          AppStorage.inMemory(initialPip: pip),
          clock: () => now,
        );

    test('a segment from his station: one more, up to full', () {
      final pip = start(PipLife(
        born: DateTime(2026, 10, 1),
        energy: 1.2,
        energyAt: now,
        nextBatteryAt: now.add(const Duration(hours: 5)),
      ));
      expect(pip.chargeTick(now), isTrue);
      expect(pip.levelAt(now), closeTo(2.2, 1e-9));
      expect(pip.chargeTick(now), isTrue);
      expect(pip.levelAt(now), 3);
      expect(pip.chargeTick(now), isFalse, reason: 'full');
      expect(pip.state.batteries, 0, reason: 'no battery used');
    });

    test('off: on again', () {
      final pip = start(PipLife(
        born: DateTime(2026, 10, 1),
        energy: 0,
        energyAt: now,
        offSeen: true,
        nextBatteryAt: now.add(const Duration(hours: 5)),
      ));
      expect(pip.showAt(now), PipShow.off);
      expect(pip.chargeTick(now), isTrue);
      expect(pip.state.offSeen, isFalse);
      expect(pip.levelAt(now), 1);
      expect(pip.showAt(now), PipShow.awake);
      expect(pip.segmentsAt(now), 1);
    });

    test('an egg: nothing', () {
      final pip = start(PipLife(energy: 1, energyAt: now));
      expect(pip.state.hatched, isFalse);
      expect(pip.chargeTick(now), isFalse);
      expect(pip.state.energy, 1);
    });

    test('plugged in a long while: his icon shows what he has', () {
      final pip = start(PipLife(
        born: DateTime(2026, 10, 1),
        energy: 3,
        energyAt: now,
        nextBatteryAt: now.add(const Duration(hours: 5)),
      ))
        ..resumeCharging(true);
      final later = now.add(const Duration(hours: 6));
      expect(pip.levelAt(later), closeTo(1.5, 1e-9));
      expect(pip.segmentsAt(later), 2);
      expect(PipEnergy.segments(pip.state.energy), 3,
          reason: 'what he had then');
    });
  });
}
