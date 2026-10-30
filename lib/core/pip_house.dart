import 'package:the_app/core/pip_quest.dart';

/// Pip's house (Round 126, `docs/QUESTS_SPEC.md` section 6): how much of
/// each piece stands, from his quest's progress, and where he stands to
/// work on each. Drawn by `widgets/pip_house_art.dart`.
///
/// The house's own measures are in his pixels, x from the house area's
/// left, y in rows down from the sky's top as the drafts were drawn (the
/// ground's top row is [ground]): everything is placed from these.
class PipHouse {
  /// Each piece's amount up (0 to its count; the one being built has its
  /// fraction).
  final Map<String, double> _amount;

  const PipHouse._(this._amount);

  /// Nothing yet.
  static const empty = PipHouse._({});

  /// All of it.
  static final finished = PipHouse._({
    for (final p in Quests.housePieces) p.id: p.count.toDouble(),
  });

  /// As his quest stands: what's built, and the piece he's on as far as
  /// he's got with it.
  factory PipHouse.of(QuestAt at) {
    if (at.done) return finished;
    final amount = {
      for (final MapEntry(:key, :value) in at.built.entries)
        key: value.toDouble(),
    };
    final s = at.current;
    if (s.action == QuestAction.build && s.minutes > 0) {
      final id = s.piece!.id;
      amount[id] = (amount[id] ?? 0) + at.into / s.minutes;
    }
    return PipHouse._(amount);
  }

  /// How much of [id] is up (0 to its count).
  double of(String id) => _amount[id] ?? 0;

  /// How much of [id] is up, 0 to 1.
  double share(String id) {
    final piece = Quests.housePieces.where((p) => p.id == id).firstOrNull;
    if (piece == null) return 0;
    return (of(id) / piece.count).clamp(0, 1);
  }

  /// All of [id] up.
  bool has(String id) => share(id) >= 1;

  /// Anything at all.
  bool get started => _amount.values.any((v) => v > 0);

  bool get done => Quests.housePieces.every((p) => has(p.id));

  /// The scaffold stands from when it's put up till it's taken down.
  bool get scaffoldUp => of('scaffold') > 0 && !has('scaffoldDown');

  /// The roof's begun (rafters up) but isn't closed (rain gets in).
  bool get roofOpen =>
      of('rafters') > 0 && !(has('shingles') && has('porchRoof'));

  /// No roof begun yet: the sky's over the walls.
  bool get roofless => of('rafters') == 0;

  // The house's measures (the drafts', Round 124).
  static const ground = 145;
  static const left = 4, right = 90; // the walls' outer edges
  static const foundationTop = 139;
  static const floorTop = 137;
  static const wallTop = 96;
  static const beamTop = 93;
  static const porchLeft = right + 1, porchRight = right + 44;
  static const fireplaceLeft = 12, fireplaceRight = 32;
  static const flueLeft = 17, flueRight = 27;
  static const middlePost = 58;
  static const windows = [(37, 104), (66, 104)];
  static const eaveLeft = left - 6, eaveRight = right + 6;
  static const apex = (left + right) ~/ 2;
  static const scaffoldLow = 118, scaffoldHigh = 99;

  /// How wide the house area is (the house, its porch and stairs, the
  /// tree beside them), in his pixels.
  static const areaWidth = 180;

  /// Where the house area's tree stands (its left edge).
  static const treeLeft = areaWidth - 42;

  /// How high above the ground (in his pixels) he stands on the floor,
  /// the porch deck, and the scaffold's planks.
  static const onGround = 0.0;
  static const onFloor = ground - floorTop - 1.0;
  static const onScaffold = ground - scaffoldHigh - 1.0;

  /// Where he stands to work on [piece]'s [index]th (his middle, in house
  /// x), and how high: on the ground, the floor or the scaffold.
  static (double, double) workSpot(String piece, int index, int count) {
    double along(double from, double to) =>
        count <= 1 ? (from + to) / 2 : from + (to - from) * index / (count - 1);
    return switch (piece) {
      'foundation' => (along(left + 4, right - 4), onGround),
      'porchPosts' => (
          [porchLeft + 14.0, porchLeft + 30.0, porchRight - 2.0][index % 3],
          onGround
        ),
      'deck' => (along(porchLeft + 4, porchRight - 4), onGround),
      'stairs' => (porchRight + 6.0 + index * 4, onGround),
      'floor' => (along(left + 6, right - 6), onFloor),
      'hearth' || 'flue' => (fireplaceRight + 8.0, onFloor),
      'posts' => (
          [left + 10.0, middlePost + 2.0, right - 10.0][index % 3],
          onFloor
        ),
      'walls' => (along(left + 10, right - 10), onFloor),
      'windows' || 'flowerBoxes' => (windows[index % 2].$1 + 9.0, onFloor),
      'door' => (right - 12.0, onFloor),
      'railing' => (along(porchLeft + 16, porchRight - 4), onFloor),
      'porchRoofPosts' => (
          [porchLeft + 13.0, porchRight - 2.0][index % 2],
          onFloor
        ),
      'beam' => (apex.toDouble(), onFloor),
      'scaffold' || 'scaffoldDown' => (middlePost + 2.0, onFloor),
      'rafters' || 'gable' || 'trim' => (
          along(left + 14, right - 14),
          onScaffold
        ),
      'atticWindow' => (apex.toDouble(), onScaffold),
      'shingles' => (along(left + 14, right - 14), onScaffold),
      'flueCap' => (flueRight + 8.0, onScaffold),
      'porchRoof' => (along(porchLeft + 8, porchRight - 4), onFloor),
      'bench' => (porchLeft + 27.0, onFloor),
      _ => (apex.toDouble(), onFloor),
    };
  }

  /// Where he smelts glass: by the fireplace.
  static const (double, double) smeltSpot = (fireplaceRight + 8.0, onFloor);
}
