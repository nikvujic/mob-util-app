/// Pip's quests (Round 125, `docs/QUESTS_SPEC.md`): plain rules, worked
/// out from the clock as his energy and adventures are. A quest is a
/// fixed **script** of steps, each taking a set number of **work
/// minutes**; from the work minutes alone come the step he's on, how
/// far into it he is, what's built and what he carries.
abstract final class PipQuest {
  /// Quest hours (local time, minutes of the day): 10:00–11:30 and
  /// 19:00–20:30, three hours a day.
  static const windows = [(10 * 60, 11 * 60 + 30), (19 * 60, 20 * 60 + 30)];
  static const minutesPerDay = 180;

  static int _minuteOfDay(DateTime t) => t.hour * 60 + t.minute;

  /// Whether [t] is in quest hours.
  static bool inHoursAt(DateTime t) {
    final m = _minuteOfDay(t);
    return windows.any((w) => m >= w.$1 && m < w.$2);
  }

  /// A quest can be started only in quest hours (as an adventure is
  /// registered only in its own).
  static bool canStartAt(DateTime t) => inHoursAt(t);

  /// The quest hours between [from] and [to], in order, each cut to that
  /// span (none if the clock went back).
  static List<(DateTime, DateTime)> windowsBetween(DateTime from, DateTime to) {
    final spans = <(DateTime, DateTime)>[];
    if (!to.isAfter(from)) return spans;
    var day = DateTime(from.year, from.month, from.day);
    // Bounded: years away are counted, but not forever.
    for (var i = 0; i < 2000 && day.isBefore(to); i++) {
      for (final (a, b) in windows) {
        final start = day.add(Duration(minutes: a));
        final end = day.add(Duration(minutes: b));
        final s = start.isBefore(from) ? from : start;
        final e = end.isAfter(to) ? to : end;
        if (e.isAfter(s)) spans.add((s, e));
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return spans;
  }

  /// About when [left] more work minutes are done, from [now], if no
  /// quest hours are lost (powered down, away): the moment within the
  /// window that holds the last of them.
  static DateTime finishAt(DateTime now, int left) {
    var remaining = left;
    var day = DateTime(now.year, now.month, now.day);
    for (var i = 0; i < 4000; i++) {
      for (final (a, b) in windows) {
        final start = day.add(Duration(minutes: a));
        final end = day.add(Duration(minutes: b));
        final s = start.isBefore(now) ? now : start;
        if (!end.isAfter(s)) continue;
        final room = end.difference(s).inMinutes;
        if (remaining <= room) return s.add(Duration(minutes: remaining));
        remaining -= room;
      }
      day = DateTime(day.year, day.month, day.day + 1);
    }
    return day;
  }
}

/// What he gathers and builds with.
enum QuestItem {
  wood('Wood'),
  stone('Stone'),
  sand('Sand'),
  glass('Glass');

  final String label;
  const QuestItem(this.label);
}

/// Where a step happens: his house area, or out gathering.
enum QuestPlace { house, forest, mine, beach }

/// What a step is.
enum QuestAction {
  /// From the house area out to a gathering place (or back).
  walkOut,
  walkBack,

  /// Felling a tree, breaking stone, digging sand.
  gather,

  /// Smelting glass in the fireplace.
  smelt,

  /// A piece of the house put in place.
  build,
}

/// One step of a quest's script.
class QuestStep {
  final QuestAction action;
  final QuestPlace place;
  final int minutes;

  /// What goes into it when it starts (a piece's materials), and what
  /// comes of it when it's done (wood from a tree, a pane of glass).
  final Map<QuestItem, int> takes;
  final Map<QuestItem, int> gives;

  /// The piece it builds, and which of them (0 up).
  final QuestPiece? piece;
  final int index;

  const QuestStep(
    this.action,
    this.place,
    this.minutes, {
    this.takes = const {},
    this.gives = const {},
    this.piece,
    this.index = 0,
  });
}

/// A kind of piece of the house: how many, what each costs, how long
/// each takes. Built in the order listed, each on what's below it.
class QuestPiece {
  final String id;

  /// For the quest card: "Laying the floor".
  final String doing;
  final int count;
  final Map<QuestItem, int> cost;
  final int minutes;

  const QuestPiece(this.id, this.doing, this.count, this.cost, this.minutes);
}

/// Where a quest is after some work minutes.
class QuestAt {
  final QuestScript script;

  /// The step he's on (the last, done, once it's finished) and the minutes
  /// into it.
  final int step;
  final int into;
  final Map<QuestItem, int> inventory;

  /// How many of each piece (by its id) are in place.
  final Map<String, int> built;
  final bool done;

  const QuestAt(
      this.script, this.step, this.into, this.inventory, this.built, this.done);

  QuestStep get current => script.steps[step];

  /// How far along the whole quest is, 0 to 1.
  double get fraction =>
      done ? 1 : (script.startOf(step) + into) / script.totalMinutes;

  /// What he's on now, for the quest card: "Chopping wood: 37 of 264
  /// wood", "Laying the floor: 5 of 17".
  String get doing {
    if (done) return 'Done';
    final s = current;
    final piece = s.piece;
    switch (s.action) {
      case QuestAction.build:
        return '${piece!.doing}: ${s.index + 1} of ${piece.count}';
      case QuestAction.smelt:
        final had = built['_glass'] ?? 0;
        return 'Making glass: ${had + 1} of ${script.needs[QuestItem.glass]}';
      case QuestAction.walkOut:
        return 'Walking to the ${_placeName(s.place)}';
      case QuestAction.walkBack:
        return 'Walking home';
      case QuestAction.gather:
        final (verb, item) = switch (s.place) {
          QuestPlace.forest => ('Chopping wood', QuestItem.wood),
          QuestPlace.mine => ('Mining stone', QuestItem.stone),
          _ => ('Digging sand', QuestItem.sand),
        };
        final got = gathered[item] ?? 0;
        return '$verb: $got of ${script.gathers[item]} ${item.label.toLowerCase()}';
    }
  }

  static String _placeName(QuestPlace p) => switch (p) {
        QuestPlace.forest => 'forest',
        QuestPlace.mine => 'mine',
        QuestPlace.beach => 'beach',
        QuestPlace.house => 'house',
      };

  /// What's been gathered so far, of each.
  Map<QuestItem, int> get gathered {
    final got = <QuestItem, int>{};
    for (var i = 0; i < step; i++) {
      final s = script.steps[i];
      if (s.action != QuestAction.gather) continue;
      s.gives.forEach((k, v) => got[k] = (got[k] ?? 0) + v);
    }
    return got;
  }
}

/// A quest's whole script.
class QuestScript {
  final String id;
  final String name;

  /// A line about it, for the quest card.
  final String about;
  final List<QuestStep> steps;
  late final List<int> _starts;
  late final int totalMinutes;

  /// What's gathered of each over the whole quest, and what's made
  /// (glass).
  late final Map<QuestItem, int> gathers;
  late final Map<QuestItem, int> needs;

  QuestScript(this.id, this.name, this.steps, {this.about = ''}) {
    var at = 0;
    _starts = [
      for (final s in steps) (at += s.minutes) - s.minutes,
    ];
    totalMinutes = at;
    final g = <QuestItem, int>{}, n = <QuestItem, int>{};
    for (final s in steps) {
      final into = s.action == QuestAction.gather ? g : n;
      s.gives.forEach((k, v) => into[k] = (into[k] ?? 0) + v);
    }
    gathers = g;
    needs = n;
  }

  int startOf(int step) => _starts[step];

  /// Where it is after [minutes] of work.
  QuestAt at(int minutes) {
    final m = minutes < 0 ? 0 : minutes;
    if (m >= totalMinutes) {
      return QuestAt(
          this,
          steps.length - 1,
          steps.last.minutes,
          _inventoryAfter(steps.length, startedLast: false),
          _builtAfter(steps.length),
          true);
    }
    // The last step started at or before m.
    var lo = 0, hi = steps.length - 1;
    while (lo < hi) {
      final mid = (lo + hi + 1) ~/ 2;
      if (_starts[mid] <= m) {
        lo = mid;
      } else {
        hi = mid - 1;
      }
    }
    return QuestAt(this, lo, m - _starts[lo],
        _inventoryAfter(lo, startedLast: true), _builtAfter(lo), false);
  }

  /// What he carries once [count] steps are done, and (if
  /// [startedLast]) the next one started: its materials gone into it.
  Map<QuestItem, int> _inventoryAfter(int count, {required bool startedLast}) {
    final inv = {for (final i in QuestItem.values) i: 0};
    for (var i = 0; i < count; i++) {
      final s = steps[i];
      s.takes.forEach((k, v) => inv[k] = inv[k]! - v);
      s.gives.forEach((k, v) => inv[k] = inv[k]! + v);
    }
    if (startedLast && count < steps.length) {
      steps[count].takes.forEach((k, v) => inv[k] = inv[k]! - v);
    }
    return inv;
  }

  Map<String, int> _builtAfter(int count) {
    final built = <String, int>{};
    for (var i = 0; i < count; i++) {
      final s = steps[i];
      if (s.action == QuestAction.build) {
        built[s.piece!.id] = (built[s.piece!.id] ?? 0) + 1;
      } else if (s.action == QuestAction.smelt) {
        built['_glass'] = (built['_glass'] ?? 0) + 1;
      }
    }
    return built;
  }
}

/// The quests, in the order they're offered (spec 1: a chain).
abstract final class Quests {
  static final house = _house();
  static final all = [house];

  static QuestScript? byId(String? id) =>
      all.where((q) => q.id == id).firstOrNull;

  /// The next quest to offer after those [done] (by id), or null.
  static QuestScript? nextAfter(Iterable<String> done) =>
      all.where((q) => !done.contains(q.id)).firstOrNull;

  // Gathering (minutes). A walk out or back; a tree felled (4 wood); a
  // block of stone broken off; a heap of sand dug; a pane smelted (two
  // sand and a wood). What he carries home at most, of each.
  static const walk = 5;
  static const treeMinutes = 32;
  static const woodPerTree = 4;
  static const stoneMinutes = 16;
  static const sandMinutes = 8;
  static const smeltMinutes = 25;
  static const carry = {
    QuestItem.wood: 12,
    QuestItem.stone: 8,
    QuestItem.sand: 12
  };

  /// The house's pieces (spec 6, the order decided in Round 123–124),
  /// each on what's built before it.
  static const housePieces = [
    QuestPiece(
        'foundation', 'Laying the foundation', 30, {QuestItem.stone: 2}, 20),
    QuestPiece('porchPosts', 'Setting the porch posts', 3,
        {QuestItem.wood: 2, QuestItem.stone: 1}, 35),
    QuestPiece('deck', 'Laying the porch deck', 9, {QuestItem.wood: 2}, 18),
    QuestPiece('stairs', 'Building the stairs', 4, {QuestItem.wood: 2}, 30),
    QuestPiece('floor', 'Laying the floor', 17, {QuestItem.wood: 2}, 18),
    QuestPiece(
        'hearth', 'Building the fireplace', 12, {QuestItem.stone: 2}, 25),
    QuestPiece('posts', 'Raising the posts', 3, {QuestItem.wood: 4}, 45),
    QuestPiece('walls', 'Building the walls', 40, {QuestItem.wood: 2}, 20),
    QuestPiece('windows', 'Setting the windows', 2,
        {QuestItem.glass: 4, QuestItem.wood: 2}, 60),
    QuestPiece('door', 'Hanging the door', 1,
        {QuestItem.wood: 6, QuestItem.stone: 2}, 120),
    QuestPiece('railing', 'Putting up the railing', 6, {QuestItem.wood: 1}, 25),
    QuestPiece('porchRoofPosts', 'Raising the porch roof posts', 2,
        {QuestItem.wood: 3}, 45),
    QuestPiece('beam', 'Raising the ceiling beam', 1, {QuestItem.wood: 6}, 120),
    QuestPiece('flue', 'Building the chimney', 10, {QuestItem.stone: 2}, 25),
    QuestPiece(
        'scaffold', 'Putting up the scaffold', 1, {QuestItem.wood: 10}, 90),
    QuestPiece('rafters', 'Raising the rafters', 8, {QuestItem.wood: 3}, 35),
    QuestPiece('gable', 'Boarding the gable', 14, {QuestItem.wood: 2}, 20),
    QuestPiece('atticWindow', 'Setting the attic window', 1,
        {QuestItem.glass: 1, QuestItem.wood: 1}, 60),
    QuestPiece('shingles', 'Laying the shingles', 60, {QuestItem.wood: 1}, 14),
    QuestPiece('porchRoof', 'Roofing the porch', 12, {QuestItem.wood: 1}, 14),
    QuestPiece('bench', 'Making the bench', 1, {QuestItem.wood: 4}, 75),
    QuestPiece('trim', 'Fitting the trim', 10, {QuestItem.wood: 1}, 12),
    QuestPiece('flueCap', 'Capping the chimney', 1, {QuestItem.stone: 2}, 40),
    QuestPiece(
        'flowerBoxes', 'Making the flower boxes', 2, {QuestItem.wood: 2}, 40),
    QuestPiece('scaffoldDown', 'Taking down the scaffold', 1, {}, 60),
  ];

  static QuestScript _house() {
    final steps = <QuestStep>[];
    final inv = {for (final i in QuestItem.values) i: 0};

    void trip(QuestItem item, int needed) {
      final place = switch (item) {
        QuestItem.wood => QuestPlace.forest,
        QuestItem.stone => QuestPlace.mine,
        _ => QuestPlace.beach,
      };
      while (inv[item]! < needed) {
        steps.add(QuestStep(QuestAction.walkOut, place, walk));
        var load = 0;
        while (inv[item]! < needed && load < carry[item]!) {
          final (minutes, n) = switch (item) {
            QuestItem.wood => (treeMinutes, woodPerTree),
            QuestItem.stone => (stoneMinutes, 1),
            _ => (sandMinutes, 1),
          };
          steps.add(
              QuestStep(QuestAction.gather, place, minutes, gives: {item: n}));
          inv[item] = inv[item]! + n;
          load += n;
        }
        steps.add(QuestStep(QuestAction.walkBack, place, walk));
      }
    }

    void glass(int needed) {
      if (inv[QuestItem.glass]! >= needed) return;
      final more = needed - inv[QuestItem.glass]!;
      trip(QuestItem.sand, more * 2);
      trip(QuestItem.wood, more);
      for (var i = 0; i < more; i++) {
        steps.add(QuestStep(QuestAction.smelt, QuestPlace.house, smeltMinutes,
            takes: {QuestItem.sand: 2, QuestItem.wood: 1},
            gives: {QuestItem.glass: 1}));
        inv[QuestItem.sand] = inv[QuestItem.sand]! - 2;
        inv[QuestItem.wood] = inv[QuestItem.wood]! - 1;
        inv[QuestItem.glass] = inv[QuestItem.glass]! + 1;
      }
    }

    for (final piece in housePieces) {
      // Gather what all of this piece needs, then build them one by one.
      for (final MapEntry(key: item, value: each) in piece.cost.entries) {
        final needed = each * piece.count;
        if (item == QuestItem.glass) {
          glass(needed);
        } else {
          trip(item, needed);
        }
      }
      for (var i = 0; i < piece.count; i++) {
        steps.add(QuestStep(QuestAction.build, QuestPlace.house, piece.minutes,
            takes: piece.cost, piece: piece, index: i));
        piece.cost.forEach((k, v) => inv[k] = inv[k]! - v);
      }
    }
    return QuestScript('house', 'Build a house', steps,
        about: 'Wood from the forest, stone from the mine, sand from the '
            'beach for glass: a house, piece by piece. About two months.');
  }
}
