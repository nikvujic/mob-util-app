import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_run.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/widgets/pip_room.dart';

import '../helpers.dart';

/// Round 152: the app brought back (or opened) at 12:38 on him out on his
/// adventure since 12:00, the rain learned a moment later (the weather's
/// fetched once the app's open): he's simply out running, from the first
/// look; no umbrella going up and down, no looking up, his field's trees
/// not jumping.
void main() {
  for (final resumed in [true, false]) {
    for (final rainFirst in [false, true]) {
      testWidgets(
          '${resumed ? 'brought back' : 'opened'} at 12:38 on his '
          'adventure, the rain known ${rainFirst ? 'at once' : 'a moment '
              'later'}', (tester) async {
        final link = FakePipLink()..at = DateTime(2026, 11, 18, 11, 50);
        final brain = PipBrain(random: math.Random(2));
        int? code = resumed ? 0 : (rainFirst ? 61 : null); // 0 clear, 61 rain
        late StateSetter set;
        Future<void> mount() => tester.pumpWidget(Directionality(
              textDirection: TextDirection.ltr,
              child: MediaQuery(
                data: const MediaQueryData(),
                child: Align(
                  alignment: Alignment.topLeft,
                  child: SizedBox(
                    width: 400,
                    child: StatefulBuilder(builder: (context, setState) {
                      set = setState;
                      return PipRoom(
                        brain: brain,
                        animate: true,
                        link: link,
                        scene: PipScene.at(PipPlace.room, link.at!,
                            weatherCode: code),
                      );
                    }),
                  ),
                ),
              ),
            ));
        void out() => link
          ..at = DateTime(2026, 11, 18, 12, 38)
          ..out = (onBreak: false, breakDone: 0.0)
          ..running = 38 * 60.0;
        if (resumed) {
          // Watched at 11:50, dry, on his field; then the app put away.
          await mount();
          for (var i = 0; i < 30; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
          expect(brain.activity, isNot(PipActivity.adventuring));
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.hidden);
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.paused);
          out();
          if (rainFirst) code = 61;
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.hidden);
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.inactive);
          tester.binding
              .handleAppLifecycleStateChanged(AppLifecycleState.resumed);
          set(() {});
          // The first frame back: after a long while (checked at once).
          await tester.pump(const Duration(seconds: 2));
        } else {
          out();
          await mount();
        }
        double? trees;
        for (var i = 0; i < 60; i++) {
          if (i == 10 && !rainFirst) set(() => code = 61);
          await tester.pump(const Duration(milliseconds: 100));
          link.running = link.running! + 0.1;
          expect(brain.activity, PipActivity.adventuring,
              reason: 'simply out, frame $i');
          expect(brain.run!.phase,
              isNot(anyOf(RunPhase.toCentre, RunPhase.drawing)),
              reason: 'running already, not setting off: frame $i');
          expect(brain.umbrella, 0, reason: 'no umbrella up and down');
          final now = brain.treeRun;
          if (trees != null && now != null) {
            expect((now - trees).abs(), lessThan(2),
                reason: 'the trees going by, not jumping');
          }
          trees = now;
        }
        expect(brain.weather?.wet, isTrue, reason: 'the rain known');
      });
    }
  }

  testWidgets(
      'brought back, the rain learned a moment later: not noticed (no '
      'looking up), his umbrella simply up, not seen opening', (tester) async {
    final link = FakePipLink()..at = DateTime(2026, 11, 18, 15, 0);
    final brain = PipBrain(random: math.Random(4));
    int? code = 0;
    late StateSetter set;
    await tester.pumpWidget(Directionality(
      textDirection: TextDirection.ltr,
      child: MediaQuery(
        data: const MediaQueryData(),
        child: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: 400,
            child: StatefulBuilder(builder: (context, setState) {
              set = setState;
              return PipRoom(
                brain: brain,
                animate: true,
                link: link,
                scene: PipScene.at(PipPlace.room, link.at!, weatherCode: code),
              );
            }),
          ),
        ),
      ),
    ));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (final s in [
      AppLifecycleState.inactive,
      AppLifecycleState.hidden,
      AppLifecycleState.paused,
      AppLifecycleState.hidden,
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]) {
      tester.binding.handleAppLifecycleStateChanged(s);
    }
    link.at = DateTime(2026, 11, 18, 16, 0);
    await tester.pump(const Duration(seconds: 2));
    for (var i = 0; i < 40; i++) {
      if (i == 10) set(() => code = 61);
      await tester.pump(const Duration(milliseconds: 100));
      expect(brain.activity, isNot(PipActivity.lookingUp),
          reason: 'not noticed: frame $i');
      if (i > 10 && brain.activity == PipActivity.standing) {
        expect(brain.umbrella, anyOf(0.0, 1.0),
            reason: 'simply up, not opening: frame $i');
      }
    }
  });
}
