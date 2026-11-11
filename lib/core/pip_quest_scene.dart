import 'dart:math' as math;

import 'package:the_app/core/pip_house.dart';
import 'package:the_app/core/pip_quest.dart';

/// Where his quest's work is shown (Round 127): his house area, the
/// field on the way, or a place he gathers in.
enum QuestScenePlace { house, field, forest, mine, beach }

/// What he's doing in it.
enum QuestPose { walking, working, standing }

/// One of what he carries, flying (to him, or into a piece): its kind,
/// where (x as [QuestView.pipCentre] is measured, y up from the ground).
typedef QuestFlyer = ({String item, double x, double up});

/// A puff of dust or smoke: where, and how far through it (0 to 1).
typedef QuestPuff = ({double x, double up, double t});

/// What his quest's work looks like at a moment (Round 127, spec 4 and 7):
/// worked out from where the quest is and the seconds into its step, so
/// the app shows the same whenever it's opened. In the house area, x is
/// the house's own (`PipHouse`); in a place he gathers in, x is a share
/// of the room's width ([anchor]) plus pixels; on the field, the middle.
class QuestView {
  final QuestScenePlace place;
  final PipHouse house;

  /// His middle: [anchor] of the room's width, plus [offset] pixels (in
  /// the house area, [anchor] is 0 and [offset] the house's x).
  final double anchor;
  final double offset;

  /// How high above the ground he stands (the floor, the scaffold).
  final double lift;
  final bool facingRight;
  final QuestPose pose;

  /// On the field: how far the ground has moved (walking out or home).
  final double scroll;

  final List<QuestFlyer> flyers;
  final List<QuestPuff> puffs;

  /// The forest: how far the tree he's on has fallen (0 to 1).
  final double fall;

  /// The beach: how deep he's dug (0 to 1). The mine: how much of the
  /// boulder's left (1 to 0).
  final double dug;
  final double rock;

  /// Smelting: the fireplace glowing hot.
  final bool smelting;

  /// Seconds into the step (for what loops: swings, puffs).
  final double t;

  /// Swinging his sword (felling, breaking stone): 0 to 1 through a
  /// swing, or null.
  final double? swing;

  const QuestView({
    required this.place,
    required this.house,
    this.anchor = 0,
    required this.offset,
    this.lift = 0,
    this.facingRight = true,
    this.pose = QuestPose.working,
    this.scroll = 0,
    this.flyers = const [],
    this.puffs = const [],
    this.fall = 0,
    this.dug = 0,
    this.rock = 1,
    this.smelting = false,
    this.t = 0,
    this.swing,
  });

  /// His middle in a room [width] wide (in the house area, the house's x).
  double pipCentre(int width) => anchor * width + offset;

  /// His walking speed, in pixels a second.
  static const walkSpeed = 9.0;

  /// A swing of his sword (seconds).
  static const swingTime = 1.1;

  /// Where he goes in and out of the house area (its right edge) and
  /// stands at the foot of the stairs, coming home.
  static const edge = PipHouse.areaWidth + 12.0;
  static const home = PipHouse.porchRight + 24.0;

  /// The resource in a place, as a share of the room's width; he works
  /// at [workOffset] pixels from it.
  static double resourceAt(QuestScenePlace p) => switch (p) {
        QuestScenePlace.forest => 0.55,
        QuestScenePlace.mine => 0.2,
        _ => 0.3,
      };
  static double workOffset(QuestScenePlace p) => switch (p) {
        QuestScenePlace.forest => -2,
        QuestScenePlace.mine => -16,
        _ => -8,
      };

  static QuestScenePlace placeOf(QuestPlace p) => switch (p) {
        QuestPlace.forest => QuestScenePlace.forest,
        QuestPlace.mine => QuestScenePlace.mine,
        QuestPlace.beach => QuestScenePlace.beach,
        QuestPlace.house => QuestScenePlace.house,
      };

  static String itemOf(QuestPlace p) => switch (p) {
        QuestPlace.forest => 'wood',
        QuestPlace.mine => 'stone',
        _ => 'sand',
      };

  /// Where he works on [step] in the house area: (x, lift).
  static (double, double) spotOf(QuestStep step) => switch (step.action) {
        QuestAction.build =>
          PipHouse.workSpot(step.piece!.id, step.index, step.piece!.count),
        QuestAction.smelt => PipHouse.smeltSpot,
        _ => (home, 0),
      };

  /// What his quest looks like [seconds] into [at]'s step, in a room
  /// [width] wide. Round 144: his walks between his places go at his
  /// walking pace in any room (they took set times: slow in the house
  /// area and into the mine, quicker in a wider room).
  static QuestView of(QuestAt at, double seconds, {int width = 160}) {
    final house = PipHouse.of(at);
    if (at.done) {
      return QuestView(
          place: QuestScenePlace.house,
          house: house,
          offset: home,
          pose: QuestPose.standing);
    }
    final step = at.current;
    final length = step.minutes * 60.0;
    final t = seconds.clamp(0.0, length);
    final left = length - t;
    final place = placeOf(step.place);
    // Where he works at the place (his middle), and the walks there from
    // its left edge and in the house area.
    final workAt = resourceAt(place) * width + workOffset(place);
    final placeFor = math.min((workAt + 12) / walkSpeed, length / 3);
    switch (step.action) {
      case QuestAction.walkOut:
        // From where he was (Round 141: the last piece's spot, down off
        // it; else the stairs' foot) off the house area.
        final before = at.step > 0 ? at.script.steps[at.step - 1] : null;
        final (fromX, fromLift) = before == null ? (home, 0.0) : spotOf(before);
        final houseFor = math.min((edge - fromX).abs() / walkSpeed, length / 3);
        if (t < houseFor) {
          final p = t / houseFor;
          return QuestView(
              place: QuestScenePlace.house,
              house: house,
              offset: fromX + (edge - fromX) * p,
              lift: fromLift * (1 - math.min(1.0, p * 4)),
              pose: QuestPose.walking,
              t: t);
        }
        if (left < placeFor) {
          final p = 1 - left / placeFor;
          return QuestView(
              place: place,
              house: house,
              offset: -12 + (workAt + 12) * p,
              pose: QuestPose.walking,
              t: t);
        }
        return _onField(
            house, t, t - houseFor, length - houseFor - placeFor, width,
            right: true);
      case QuestAction.walkBack:
        final houseFor = math.min((edge - home) / walkSpeed, length / 3);
        if (t < placeFor) {
          final p = t / placeFor;
          return QuestView(
              place: place,
              house: house,
              offset: workAt - (workAt + 12) * p,
              facingRight: false,
              pose: QuestPose.walking,
              t: t);
        }
        if (left < houseFor) {
          return QuestView(
              place: QuestScenePlace.house,
              house: house,
              offset: edge - (edge - home) * (1 - left / houseFor),
              facingRight: false,
              pose: QuestPose.walking,
              t: t);
        }
        return _onField(
            house, t, t - placeFor, length - placeFor - houseFor, width,
            right: false);
      case QuestAction.gather:
        return _gather(at, house, place, t, length);
      case QuestAction.smelt || QuestAction.build:
        return _atHouse(at, house, step, t, length);
    }
  }

  /// Round 141: on his field between his places, [into] seconds of the
  /// [long] he's on it: in from one edge (the left, going [right]), the
  /// middle while the ground goes by, off the other: no cut to a place
  /// while he's in view.
  static QuestView _onField(
      PipHouse house, double t, double into, double long, int width,
      {required bool right}) {
    // In from the edge to the middle (and off) at his walking pace.
    final edgeFor = math.min((width / 2 + 12) / walkSpeed, long / 2);
    final way = right ? 1.0 : -1.0;
    // From the edge he comes in at (0 is the left, 1 the right), to the
    // middle; then the middle to the other.
    final double anchor, offset;
    if (into < edgeFor) {
      final p = into / edgeFor;
      anchor = 0.5 - way * 0.5 * (1 - p);
      offset = -way * 12 * (1 - p);
    } else if (into > long - edgeFor) {
      final p = (into - (long - edgeFor)) / edgeFor;
      anchor = 0.5 + way * 0.5 * p;
      offset = way * 12 * p;
    } else {
      anchor = 0.5;
      offset = 0;
    }
    final scrolled = (into.clamp(edgeFor, long - edgeFor) - edgeFor);
    return QuestView(
        place: QuestScenePlace.field,
        house: house,
        anchor: anchor,
        offset: offset,
        facingRight: right,
        pose: QuestPose.walking,
        scroll: way * scrolled * walkSpeed,
        t: t);
  }

  static QuestView _gather(QuestAt at, PipHouse house, QuestScenePlace place,
      double t, double length) {
    final item = itemOf(at.current.place);
    final x = workOffset(place);
    final anchor = resourceAt(place);
    final flyers = <QuestFlyer>[];
    final puffs = <QuestPuff>[];
    final swinging = place != QuestScenePlace.beach;
    // A chip with each swing; and what it gives flies to him at the end.
    final cycle = t % swingTime / swingTime;
    if (swinging && cycle > 0.5) {
      final p = (cycle - 0.5) * 2;
      puffs.add((x: x + 12, up: 10, t: p));
    }
    if (!swinging) {
      // Digging: a scoop of sand over his shoulder every two seconds.
      final p = t % 2 / 2;
      flyers.add(
          (item: item, x: x + 8 - 18 * p, up: 6 + 14 * math.sin(math.pi * p)));
    }
    final left = length - t;
    double fall = 0;
    if (place == QuestScenePlace.forest && left < 8) {
      fall = ((8 - left) / 5).clamp(0.0, 1.0);
    }
    if (left < 3) {
      final p = 1 - left / 3;
      final n = at.current.gives.values.fold(0, (a, b) => a + b);
      for (var i = 0; i < math.min(n, 4); i++) {
        final from = x + 20 + i * 4;
        flyers.add((
          item: item,
          x: from + (x - from) * p,
          up: 4 + 16 * math.sin(math.pi * p) + i,
        ));
      }
    }
    return QuestView(
      place: place,
      house: house,
      anchor: anchor,
      offset: x,
      pose: QuestPose.working,
      flyers: flyers,
      puffs: puffs,
      fall: fall,
      dug: place == QuestScenePlace.beach ? (t / length) : 0,
      rock: place == QuestScenePlace.mine ? 1 - t / length : 1,
      t: t,
      swing: swinging && fall == 0 ? cycle : null,
    );
  }

  static QuestView _atHouse(
      QuestAt at, PipHouse house, QuestStep step, double t, double length) {
    final (x, lift) = spotOf(step);
    // From where he was before (the last piece's spot, or the stairs' foot
    // coming home): a walk at the start, climbing if it's higher.
    final before = at.step > 0 ? at.script.steps[at.step - 1] : null;
    final (fromX, fromLift) = before == null ? (home, 0.0) : spotOf(before);
    final walk = math.min(((x - fromX).abs() / walkSpeed), length / 4);
    if (t < walk && walk > 0.2) {
      final p = t / walk;
      return QuestView(
        place: QuestScenePlace.house,
        house: house,
        offset: fromX + (x - fromX) * p,
        lift: fromLift + (lift - fromLift) * p,
        facingRight: x >= fromX,
        pose: QuestPose.walking,
        t: t,
      );
    }
    final work = t - walk;
    final flyers = <QuestFlyer>[];
    final puffs = <QuestPuff>[];
    // The piece in front of him: a little ahead, about his middle; at the
    // fireplace (its stones, its flue, smelting) it's on his left.
    final atFire = step.action == QuestAction.smelt ||
        step.piece?.id == 'hearth' ||
        step.piece?.id == 'flue';
    final right = !atFire;
    final pieceX = atFire
        ? (PipHouse.fireplaceLeft + PipHouse.fireplaceRight) / 2
        : x + 10;
    final pieceUp =
        atFire ? (step.piece?.id == 'flue' ? lift + 30 : lift + 8) : lift + 10;
    // His materials fly from him into it, the first moments.
    if (work < 3) {
      final p = work / 3;
      var i = 0;
      for (final MapEntry(key: item, value: n) in step.takes.entries) {
        for (var k = 0; k < math.min(n, 3); k++, i++) {
          flyers.add((
            item: item.name,
            x: x + (pieceX - x) * p + i * 2,
            up: lift + 8 + 10 * math.sin(math.pi * p) + i,
          ));
        }
      }
    }
    // Smoke as he works, now and then.
    final cycle = work % 2.4 / 2.4;
    if (cycle < 0.8) puffs.add((x: pieceX, up: pieceUp, t: cycle / 0.8));
    // Smelted: the pane comes out to him at the end.
    if (step.action == QuestAction.smelt && length - t < 3) {
      final p = 1 - (length - t) / 3;
      flyers.add((
        item: 'glass',
        x: pieceX + (x - pieceX) * p,
        up: lift + 6 + 8 * math.sin(math.pi * p),
      ));
    }
    return QuestView(
      place: QuestScenePlace.house,
      house: house,
      offset: x,
      lift: lift,
      facingRight: right,
      pose: QuestPose.working,
      flyers: flyers,
      puffs: puffs,
      smelting: step.action == QuestAction.smelt,
      t: t,
    );
  }
}
