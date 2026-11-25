import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_house.dart';
import 'package:the_app/core/pip_quest.dart';
import 'package:the_app/core/pip_quest_scene.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/pip_house_art.dart';

/// Building, he hammers (the dust where it lands, not beside
/// him); snow on an unfinished house lies on what's built.
void main() {
  final q = Quests.house;
  QuestView view(int step, double seconds) =>
      QuestView.of(q.at(q.startOf(step) + seconds ~/ 60), seconds);

  test('building: his hammer, a blow every 0.8 s, the dust where it lands', () {
    final walls = q.steps.indexWhere((s) => s.piece?.id == 'walls');
    var blows = 0;
    var dust = false;
    for (var t = 60.0; t < 64; t += 0.05) {
      final v = view(walls, t);
      expect(v.pose, QuestPose.working);
      expect(v.swing, isNotNull, reason: 'hammering at $t');
      for (final p in v.puffs) {
        expect(p.x - v.offset, closeTo(v.facingRight ? 18 : -18, 0.01),
            reason: 'in front of him, where the hammer lands');
      }
      if (v.puffs.isNotEmpty && !dust) blows++;
      dust = v.puffs.isNotEmpty;
    }
    expect(blows, inInclusiveRange(4, 6), reason: 'about 5 blows in 4 s');
    final smelt = q.steps.indexWhere((s) => s.action == QuestAction.smelt);
    expect(view(smelt, 60).swing, isNull, reason: 'smelting, no hammer');
  });

  test('snow lies on what\'s built: none where the floor isn\'t laid yet', () {
    // The floor part laid, the foundation done: snow on the floor, and
    // on the foundation past it, nothing floating where the floor will
    // be.
    final floor = [
      for (var i = 0; i < q.steps.length; i++)
        if (q.steps[i].piece?.id == 'floor') i
    ].firstWhere((i) {
      final h = PipHouse.of(q.at(q.startOf(i)));
      return h.has('foundation') && h.share('floor') < 0.9;
    });
    final house = PipHouse.of(q.at(q.startOf(floor)));
    final snow = <(int, int)>{};
    PipHouseArt((x, y, c, [w = 1, h = 1]) {
      if (c == PipHouseColours.snow) snow.add((x.round(), y.round()));
    }).house(house, snowy: true);
    // The house's own floor (the porch's deck is level with it, right of
    // it).
    final onFloor = snow
        .where((p) => p.$2 == PipHouse.floorTop - 1 && p.$1 <= PipHouse.right);
    final onFoundation = snow.where((p) => p.$2 == PipHouse.foundationTop - 1);
    expect(onFloor, isNotEmpty, reason: 'on the floor laid');
    expect(onFoundation, isNotEmpty, reason: 'on the foundation past it');
    final floorEnd = onFloor.map((p) => p.$1).reduce((a, b) => a > b ? a : b);
    expect(onFoundation.every((p) => p.$1 > floorEnd), isTrue,
        reason: 'the foundation\'s snow only past the floor');
  });

  test(
      'no stone floats: every one rests on something, at every point of the '
      "build (the chimney's cap hung two pixels over its last row)", () {
    final stone = {
      ...PipHouseColours.stone.map((c) => c.toARGB32()),
      PipHouseColours.stoneLight.toARGB32(),
      PipHouseColours.mortar.toARGB32(),
    };
    for (var i = 0; i < q.steps.length; i++) {
      for (final f in [0.1, 0.5, 0.9]) {
        final house =
            PipHouse.of(q.at(q.startOf(i) + (q.steps[i].minutes * f).floor()));
        final grid = <(int, int), int>{};
        PipHouseArt((x, y, c, [double w = 1, double h = 1]) {
          for (var dx = 0; dx < w; dx++) {
            for (var dy = 0; dy < h; dy++) {
              grid[(x.toInt() + dx, y.toInt() + dy)] = c.toARGB32();
            }
          }
        }).house(house);
        for (final MapEntry(key: (x, y), value: c) in grid.entries) {
          if (!stone.contains(c) || y >= PipHouse.ground - 1) continue;
          // The cap's ends overhang the chimney, as a cap's do; its middle
          // rests on it.
          final capEnd = grid[(PipHouse.flueLeft, y + 1)] != null &&
              (x < PipHouse.flueLeft || x > PipHouse.flueRight) &&
              x >= PipHouse.flueLeft - 2 &&
              x <= PipHouse.flueRight + 2 &&
              y < 70;
          if (capEnd) continue;
          expect(grid[(x, y + 1)], isNotNull,
              reason: 'step $i (${q.steps[i].piece?.id}): stone at ($x, $y) '
                  'over nothing');
        }
      }
    }
  });
}
