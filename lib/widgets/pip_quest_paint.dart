import 'dart:math' as math;
import 'dart:ui';

import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_house.dart';
import 'package:the_app/core/pip_quest_scene.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/core/weather.dart';
import 'package:the_app/widgets/pip_house_art.dart';

/// Draws his quest's place behind him (Round 127): his house area (the
/// house as far as it's built, its tree, the weather on it), or the
/// forest, the mine, the beach; what flies, the dust and smoke; a lantern
/// after dark. [dot] draws in room pixels; [groundTop] is the ground's
/// top row; the room is [columns] wide.
void paintQuestPlace(
  void Function(double x, double y, Color c, [double w, double h]) dot,
  double groundTop,
  int columns,
  PipBrain brain,
  QuestView view,
  PipScene? scene,
) {
  final house = view.place == QuestScenePlace.house;
  final camera = house ? brain.questCamera : 0.0;
  // The art's rows: its ground's top row at [PipHouse.ground].
  final art = PipHouseArt((x, y, c, [double w = 1.0, double h = 1.0]) =>
      dot(x - camera, groundTop + (y - PipHouse.ground), c, w, h));
  const g = PipHouse.ground - 1.0;
  final season = scene?.season ?? Season.summer;
  final props = scene?.props ?? const <PipProp>{};
  final raining = props.contains(PipProp.rain);
  final snowy = scene?.snowyGround ?? false;
  final dark = brain.dark;
  final centre = view.pipCentre(columns);
  switch (view.place) {
    case QuestScenePlace.house:
      final sway = switch (scene?.wind ?? PipWind.calm) {
        PipWind.calm => 0.0,
        _ => (math.sin(view.t * 1.6) * 1.2).roundToDouble(),
      };
      art.tree(season, PipHouse.treeLeft.toDouble(), g, sway: sway);
      art.house(view.house,
          fire: view.house.has('hearth'), raining: raining, snowy: snowy);
      if (view.house.has('flueCap')) art.chimneySmoke(view.t);
      if (view.smelting) {
        // The fireplace roaring: its glow.
        _glow(art, (PipHouse.fireplaceLeft + PipHouse.fireplaceRight) / 2,
            PipHouse.floorTop - 6.0, 14, PipHouseColours.fire);
      }
    case QuestScenePlace.forest:
      art.forest(g, columns, season);
      art.fellingTree(season, QuestView.resourceAt(view.place) * columns - 13,
          g, view.fall);
    case QuestScenePlace.mine:
      art.gravel(PipHouse.ground.toDouble(), columns, 6);
      art.mine(g, columns);
      art.boulder(QuestView.resourceAt(view.place) * columns + 2, g,
          view.rock.clamp(0.0, 1.0));
    case QuestScenePlace.beach:
      art.beach(g, columns, 6, view.t);
      art.bucketAndHole(QuestView.resourceAt(view.place) * columns + 2, g,
          view.dug.clamp(0.0, 1.0));
    case QuestScenePlace.field:
      break;
  }
  // After dark, a lantern: on the porch's post once it's up, else by him.
  if (dark) {
    final (lx, ly) = house && view.house.has('porchRoofPosts')
        ? (PipHouse.porchRight - 6.0, 99.0)
        : (centre + 9, PipHouse.ground - view.lift - 12);
    art.lantern(lx, ly);
    _glow(art, lx + 1, ly + 2, 16, PipHouseColours.lantern);
  }
  for (final f in view.flyers) {
    art.item(f.item, f.x - 1, PipHouse.ground - f.up);
  }
  for (final p in view.puffs) {
    art.puff(p.x, PipHouse.ground - p.up, p.t);
  }
}

/// A soft round light of [colour] round [cx], [cy], [r] across.
void _glow(PipHouseArt art, double cx, double cy, int r, Color colour) {
  for (var ring = r; ring > 2; ring -= 4) {
    final a = 0.07 * (1 - ring / r) + 0.03;
    for (var y = -ring; y <= ring; y += 2) {
      for (var x = -ring; x <= ring; x += 2) {
        if (x * x + y * y > ring * ring) continue;
        art.rect(cx + x, cy + y, cx + x + 1, cy + y + 1,
            colour.withValues(alpha: a));
      }
    }
  }
}
