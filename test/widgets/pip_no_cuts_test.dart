import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/core/pip_quest.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/widgets/pip_room.dart';

import '../helpers.dart';

/// Round 141: whatever his life says while he's watched (sleep, waking,
/// running out, a battery, his work's hours, his house, plugged in, a
/// medicine due, out on his adventure, taps), every frame follows from
/// the last: he only changes place out of view (or at his door), never
/// moves more than a step, and his hat never jumps.
void main() {
  final q = Quests.house;
  final issues = <String>[];
  // Seeds that found cuts before they were fixed (Round 141).
  for (final seed in const [10, 17, 23, 57, 62]) {
    testWidgets(
        'Round 141: watched through a random life (seed $seed), he never '
        'jumps: no cut between places in view, no jump in where he is, no '
        'hat jumping', (tester) async {
      final r = math.Random(seed);
      final link = FakePipLink()
        ..at = DateTime(2026, 11, 2, 10, 30)
        ..partyHat = r.nextBool();
      final brain = PipBrain(random: math.Random(seed));
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
                  scene: PipScene.at(PipPlace.home, link.at!)),
            ),
          ),
        ),
      ));
      final log = <String>[];
      double? work; // seconds of quest work, while in hours
      bool hours = false;
      void setQuest() {
        final w = work;
        if (!hours || w == null || link.show != PipShow.awake) {
          link.questing = null;
          return;
        }
        final at = q.at(w ~/ 60);
        link.questing = (at: at, seconds: at.into * 60 + w % 60);
      }

      String place() => brain.run != null
          ? 'field'
          : brain.questView?.place.name ?? (brain.atHome ? 'home' : 'field');
      bool visible() =>
          brain.x + PipBrain.width > 0 && brain.x < brain.roomWidth;
      double hatAt() =>
          brain.hat == null ? -1 : brain.hatHop ?? (brain.hatBeside ? 0 : 1);
      // Settle in a while first.
      for (var i = 0; i < 60; i++) {
        await tester.pump(const Duration(milliseconds: 50));
      }
      var pPlace = place(), pX = brain.x, pVis = visible(), pHat = hatAt();
      var pCam = brain.questCamera, pAct = brain.activity;
      var next = 0.0;
      for (var f = 0; f < 20 * 60 * 3; f++) {
        final t = f * 0.05;
        if (t >= next) {
          next = t + 2 + r.nextDouble() * 14;
          final roll = r.nextInt(12);
          String what = '';
          switch (link.show) {
            case PipShow.asleep || PipShow.fallAsleep:
              if (roll < 6) {
                link.show = PipShow.wakeUp;
                what = 'wake';
              }
            case PipShow.off || PipShow.powerOff:
              if (roll < 4) {
                link.batteries = 1;
                await tester.tap(find.byKey(const Key('pipRoom')));
                link.show = PipShow.awake;
                what = 'battery';
              } else if (roll < 6) {
                link.show = PipShow.off;
                what = 'still off';
              }
            default:
              if (link.show == PipShow.wakeUp) link.show = PipShow.awake;
              switch (roll) {
                case 0:
                  link.show = PipShow.fallAsleep;
                  hours = false;
                  what = 'sleep';
                case 1 || 2:
                  link.show = PipShow.powerOff;
                  what = 'run out';
                case 3 || 4 when !hours && link.out == null:
                  hours = true;
                  final i = r.nextInt(q.steps.length - 1);
                  work =
                      (q.startOf(i + 1) * 60 - r.nextDouble() * 30).toDouble();
                  what = 'work on, step $i ${q.steps[i].action.name}';
                case 5 || 6:
                  hours = false;
                  what = 'work over';
                case 7:
                  link.home = !link.home;
                  what = 'home ${link.home}';
                case 8:
                  link.plugged = !link.plugged;
                  what = 'plugged ${link.plugged}';
                case 9:
                  link.medicineDue = !link.medicineDue;
                  what = 'medicine ${link.medicineDue}';
                case 10:
                  await tester.tap(find.byKey(const Key('pipRoom')));
                  what = 'tap';
                case 11 when !hours:
                  link.out = link.out == null
                      ? (onBreak: false, breakDone: 0.0)
                      : null;
                  link.running = link.out == null ? null : 0;
                  what = 'out ${link.out != null}';
                default:
              }
          }
          if (what.isNotEmpty) log.add('${t.toStringAsFixed(1)} $what');
        }
        if (link.running case final running?) link.running = running + 0.05;
        if (work case final w? when hours && link.show == PipShow.awake) {
          work = w + 0.05;
        }
        setQuest();
        await tester.pump(const Duration(milliseconds: 50));
        final pl = place(), x = brain.x, vis = visible(), hat = hatAt();
        final cam = brain.questCamera, act = brain.activity;
        String? bad;
        final atDoor = (pPlace == 'home' &&
                (pX - (PipBrain.homeRight - PipBrain.width)).abs() < 3) ||
            (pPlace == 'house' && pl == 'home');
        if (pl != pPlace && pVis && !atDoor) {
          bad = 'CUT $pPlace->$pl';
        } else if (pl == pPlace && pVis && vis && (x - pX).abs() > 8) {
          bad = 'JUMP x ${pX.toStringAsFixed(0)}->${x.toStringAsFixed(0)}';
        } else if (pl == pPlace && (cam - pCam).abs() > 8) {
          bad = 'CAMERA ${pCam.toStringAsFixed(0)}->${cam.toStringAsFixed(0)}';
        } else if (pHat >= 0 && hat >= 0 && (hat - pHat).abs() > 0.5 && vis) {
          bad = 'HAT $pHat->$hat';
        }
        if (bad != null) {
          final tail = log.length > 3 ? log.sublist(log.length - 3) : log;
          issues.add('seed $seed t=${t.toStringAsFixed(2)} $bad '
              '[${pAct.name}->${act.name}] after: ${tail.join(' | ')}');
        }
        pPlace = pl;
        pX = x;
        pVis = vis;
        pHat = hat;
        pCam = cam;
        pAct = act;
      }
      expect(issues.where((i) => i.startsWith('seed $seed ')), isEmpty);
    });
  }
}
