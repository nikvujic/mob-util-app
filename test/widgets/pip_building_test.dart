import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_house.dart';
import 'package:the_app/core/pip_quest.dart';
import 'package:the_app/core/pip_quest_scene.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/pip_house_art.dart';

/// Round 149: building, he hammers (the dust where it lands, not beside
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
}
