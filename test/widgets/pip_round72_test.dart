import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_bus.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/widgets/pip_room.dart';
import 'package:the_app/widgets/pip_sprites.dart';

void main() {
  test(
      'the bus (Round 72): bigger, his window clear, and him in it with '
      'room around (not his whole face)', () {
    const art = PipSprites.bus;
    expect(art.length, PipBus.height);
    expect(art.every((r) => r.length == PipBus.width), isTrue);
    expect(PipBus.height, greaterThanOrEqualTo(PipBrain.height * 1.8));
    const w = PipBus.window;
    for (var y = w.top; y <= w.bottom; y++) {
      expect(
          art[y].substring(w.left, w.right + 1), '.' * (w.right - w.left + 1),
          reason: 'row $y clear');
    }
    for (final row in art) {
      for (final c in row.split('')) {
        if (c != '.') expect(PipSprites.busColours.containsKey(c), isTrue);
      }
    }
    // Him seated: his sides inside the window, glass on either side and
    // above his head.
    expect(PipBus.seatX - w.left, greaterThanOrEqualTo(2));
    expect(
        w.right + 1 - (PipBus.seatX + PipBrain.width), greaterThanOrEqualTo(2));
    final headTop = PipBus.height - PipBus.seatLift - PipBrain.height;
    expect(headTop - w.top, greaterThanOrEqualTo(2));
    expect(w.bottom, lessThan(PipBus.height - PipBus.seatLift),
        reason: 'his feet hidden by the bus');
  });

  test('trees (Round 72): a lot bigger than him, in every season', () {
    for (final art in [PipSprites.tree, PipSprites.bareTree]) {
      expect(art.length, greaterThanOrEqualTo(PipBrain.height * 1.8));
      expect(art.every((r) => r.length == art.first.length), isTrue);
      expect(PipSprites.treeCrown, lessThan(art.length));
      // The leafy one in spring to autumn, the bare one in winter.
      for (final (i, colours) in PipSprites.treeColours.indexed) {
        if ((i == Season.winter.index) != (art == PipSprites.bareTree)) {
          continue;
        }
        for (final row in art) {
          for (final c in row.split('')) {
            if (c != '.') {
              expect(colours.containsKey(c), isTrue, reason: '$i $c');
            }
          }
        }
      }
    }
  });

  test('trees (Round 72): in a random spot each time, apart', () {
    final seen = <String>{};
    for (var seed = 0; seed < 50; seed++) {
      final [(at: a, pine: _, kind: _), (at: b, pine: _, kind: _)] =
          treeSpots(math.Random(seed));
      expect(a, inInclusiveRange(0, 0.3));
      expect(b, inInclusiveRange(0.62, 1));
      seen.add('${(a * 10).floor()} ${(b * 10).floor()}');
    }
    expect(seen.length, greaterThan(5), reason: 'not the same each time');
  });

  test(
      'trees (Round 74): an oak, a birch or a pine each, at random; each '
      'drawn in every season (the pine green all year)', () {
    final kinds = <PipTreeKind>{};
    for (var seed = 0; seed < 200; seed++) {
      for (final spot in treeSpots(math.Random(seed))) {
        kinds.add(spot.kindIn(Season.winter));
        kinds.add(spot.kindIn(Season.summer));
      }
    }
    expect(kinds, PipTreeKind.values.toSet());
    for (final kind in PipTreeKind.values) {
      for (final season in Season.values) {
        final (art, colours, crown) = PipSprites.treeOf(kind, season);
        expect(art.every((r) => r.length == art.first.length), isTrue);
        expect(art.length, greaterThanOrEqualTo(PipBrain.height * 1.8),
            reason: '${kind.name}: a lot bigger than him');
        expect(crown, lessThan(art.length));
        for (final c in art.join().split('')) {
          if (c != '.') {
            expect(colours.containsKey(c), isTrue,
                reason: '${kind.name} ${season.name} $c');
          }
        }
      }
    }
    expect(PipSprites.treeOf(PipTreeKind.pine, Season.winter).$1,
        PipSprites.treeOf(PipTreeKind.pine, Season.summer).$1);
    expect(PipSprites.treeOf(PipTreeKind.birch, Season.winter).$1,
        PipSprites.bareBirch);
  });

  test(
      'the ski beanie (Round 72): down over his head, its cuff on his '
      "casing's top, as wide as it", () {
    final art = PipSprites.hats[PipHat.skiBeanie]!;
    final drop = PipSprites.hatDrop[PipHat.skiBeanie]!;
    final frame = PipSprites.frameOf(PipFrame.idle, PipFace.normal);
    final cuffRow = frame[PipSprites.hatBottom + drop];
    final left = PipSprites.hatLeftOf(art);
    expect(left, cuffRow.indexOf('L'));
    expect(left + art.first.length - 1, cuffRow.lastIndexOf('L'));
    expect(art.length, greaterThanOrEqualTo(10), reason: 'a pompom on top');
    expect(PipSprites.hatDrop.keys, [PipHat.skiBeanie], reason: 'the rest sit');
  });

  test("Christmas's things (Round 72): every colour drawn", () {
    for (final art in [PipSprites.badnjak, PipSprites.straw]) {
      for (final row in art) {
        for (final c in row.split('')) {
          if (c != '.') {
            expect(PipSprites.badnjakColours.containsKey(c), isTrue);
          }
        }
      }
    }
    expect(PipSprites.badnjak.join().contains('r'), isTrue,
        reason: 'its red ribbon');
    expect(PipSprites.candle.first.contains('f'), isTrue);
    expect(PipScene.at(PipPlace.room, DateTime(2027, 1, 7, 12)).props,
        contains(PipProp.badnjak));
  });

  test(
      'trees (Round 75): a pine rarely (5%), but mostly in winter (60%); '
      'the two the same kind but now and then (10%)', () {
    const opens = 4000;
    final pines = {for (final s in Season.values) s: 0};
    var mixed = 0;
    for (var seed = 0; seed < opens; seed++) {
      final [a, b] = treeSpots(math.Random(seed));
      for (final season in Season.values) {
        if (a.kindIn(season) == PipTreeKind.pine) {
          pines[season] = pines[season]! + 1;
        }
      }
      if (a.kindIn(Season.summer) != b.kindIn(Season.summer)) mixed++;
    }
    expect(pines[Season.summer]! / opens, closeTo(0.05, 0.015));
    expect(pines[Season.autumn]! / opens, closeTo(0.05, 0.015));
    expect(pines[Season.winter]! / opens, closeTo(0.6, 0.03));
    expect(mixed / opens, lessThan(0.1), reason: 'two kinds: rare');
    expect(mixed, greaterThan(0));
    expect(pineChance(Season.winter), 0.6);
    expect(pineChance(Season.spring), 0.05);
  });
}
