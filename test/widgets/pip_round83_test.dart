import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_run.dart';
import 'package:the_app/widgets/pip_room.dart';
import 'package:the_app/widgets/pip_sprites.dart';

/// Round 83: at the tavern he sits on his bench (not standing on it),
/// centred on it.
void main() {
  const out = (onBreak: false, breakDone: 0.0);
  const onBreak = (onBreak: true, breakDone: 0.0);

  PipBrain atTable() {
    final b = PipBrain(roomWidth: 200, random: math.Random(1));
    b.step(PipBrain.landEnd);
    b.adventure(out, animate: false);
    b.adventure(onBreak, animate: true);
    for (var i = 0; i < 60 * 30 && b.run!.phase != RunPhase.sitting; i++) {
      b.step(1 / 60);
    }
    expect(b.run!.phase, RunPhase.sitting);
    return b;
  }

  /// How high above the ground the lowest of [frame]'s rows [where]
  /// starts, lifted [lift].
  double lowest(List<String> frame, double lift, bool Function(String) where) =>
      lift + frame.length - 1 - frame.lastIndexWhere(where);

  test('sitting: his body on the bench top, his feet over its front', () {
    final b = atTable();
    final frame = pipFrameOf(b);
    final bench = PipSprites.bench.length;
    // His body: its wide rows; his feet: any.
    final body = lowest(frame, b.lift, (r) => r.replaceAll('.', '').length > 4);
    final feet = lowest(frame, b.lift, (r) => r.contains(RegExp('[^.]')));
    expect(body, bench, reason: 'his body rests on its top');
    expect(feet, lessThan(bench), reason: 'not standing on it');
    expect(feet, greaterThan(0), reason: 'his feet off the ground');
  });

  test('the bench is centred under him', () {
    final b = atTable();
    final run = b.run!;
    final benchMiddle =
        run.tavern! + PipRun.benchLeft + PipSprites.bench.first.length / 2;
    expect(b.x + PipBrain.width / 2, closeTo(benchMiddle, 1e-9));
  });
}
