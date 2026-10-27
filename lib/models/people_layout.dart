import 'dart:math' as math;

import 'package:the_app/models/people.dart';

/// The board's sizes (board units): a person's box, and the room around.
abstract final class BoardSizes {
  static const boxWidth = 120.0;
  static const boxHeight = 150.0;

  /// Between boxes side by side, and between generations.
  static const gap = 40.0;
  static const rowGap = 110.0;

  static const columnStep = boxWidth + gap;
  static const rowStep = boxHeight + rowGap;

  /// Between one family and the next, and the people with none.
  static const familyGap = boxWidth * 1.5;
}

/// Tidy (spec 5.4): everyone laid out in a default place. Each family
/// (people tied by family relations) as a tree: generations in rows,
/// parents above their children, partners side by side, brothers and
/// sisters by birth; families side by side; everyone else in a grid to
/// the right. Returns each person's new middle.
Map<String, (double, double)> tidyLayout(PeopleBook book) {
  final placed = <String, (double, double)>{};
  final done = <String>{};
  var left = 0.0;
  final singles = <Person>[];
  for (final p in book.people) {
    if (done.contains(p.id)) continue;
    final family = book.familyOf(p.id);
    done.addAll(family);
    if (family.length == 1) {
      singles.add(p);
      continue;
    }
    final tree = _treeLayout(book, family);
    final xs = tree.values.map((v) => v.$1);
    final minX = xs.reduce(math.min), maxX = xs.reduce(math.max);
    for (final MapEntry(:key, :value) in tree.entries) {
      placed[key] = (left + value.$1 - minX, value.$2);
    }
    left += maxX - minX + BoardSizes.boxWidth + BoardSizes.familyGap;
  }
  final columns = math.max(1, math.sqrt(singles.length).ceil());
  for (final (i, p) in singles.indexed) {
    placed[p.id] = (
      left + (i % columns) * BoardSizes.columnStep,
      (i ~/ columns) * BoardSizes.rowStep,
    );
  }
  return placed;
}

/// Each person's generation in [family]: parents one above their
/// children, partners and siblings on one row; the top row 0.
Map<String, int> generations(PeopleBook book, Set<String> family) {
  final gen = {for (final id in family) id: 0};
  final ties = [
    for (final r in book.relations)
      if (r.kind.family && family.contains(r.from) && family.contains(r.to)) r,
  ];
  // A few rounds settle it; bounded, so a strange tree can't loop.
  for (var round = 0; round < family.length * 2 + 2; round++) {
    var changed = false;
    void atLeast(String id, int g) {
      if (gen[id]! < g) {
        gen[id] = g;
        changed = true;
      }
    }

    for (final r in ties) {
      switch (r.kind) {
        case RelationKind.parent:
          atLeast(r.to, gen[r.from]! + 1);
          // A parent with no parents of their own sits just above.
          if (book.parentsOf(r.from).isEmpty) atLeast(r.from, gen[r.to]! - 1);
        case RelationKind.partner || RelationKind.sibling:
          final g = math.max(gen[r.from]!, gen[r.to]!);
          atLeast(r.from, g);
          atLeast(r.to, g);
        case RelationKind.other:
      }
    }
    if (!changed) break;
  }
  final top = gen.values.reduce(math.min);
  return {for (final MapEntry(:key, :value) in gen.entries) key: value - top};
}

Map<String, (double, double)> _treeLayout(PeopleBook book, Set<String> family) {
  final gen = generations(book, family);
  final order = {for (final (i, p) in book.people.indexed) p.id: i};
  final rows = <int, List<String>>{};
  for (final id in family) {
    (rows[gen[id]!] ??= []).add(id);
  }
  final x = <String, double>{};
  final result = <String, (double, double)>{};
  for (final r in rows.keys.toList()..sort()) {
    final ids = rows[r]!..sort((a, b) => order[a]!.compareTo(order[b]!));
    // Partners in a row make one unit, side by side.
    final units = <List<String>>[];
    final inUnit = <String>{};
    for (final id in ids) {
      if (inUnit.contains(id)) continue;
      final unit = <String>[id];
      inUnit.add(id);
      for (var i = 0; i < unit.length; i++) {
        for (final o in book.partnersOf(unit[i])) {
          if (ids.contains(o) && inUnit.add(o)) unit.add(o);
        }
      }
      units.add(unit);
    }
    // Under their parents (in birth order), else after.
    double key(String id) {
      final parents = [
        for (final p in book.parentsOf(id))
          if (x[p] case final px?) px,
      ];
      return parents.isEmpty
          ? double.infinity
          : parents.reduce((a, b) => a + b) / parents.length;
    }

    int born(String id) {
      final b = book.byId(id)?.birthday;
      return b == null
          ? 1 << 30
          : (b.year ?? 9999) * 400 + b.month * 31 + b.day;
    }

    double unitKey(List<String> unit) => unit.map(key).reduce(math.min);
    int unitBorn(List<String> unit) => unit.map(born).reduce(math.min);
    units.sort((a, b) {
      final byParents = unitKey(a).compareTo(unitKey(b));
      if (byParents != 0) return byParents;
      final byBirth = unitBorn(a).compareTo(unitBorn(b));
      return byBirth != 0
          ? byBirth
          : order[a.first]!.compareTo(order[b.first]!);
    });
    final line = units.expand((u) => u).toList();
    final width = (line.length - 1) * BoardSizes.columnStep;
    for (final (i, id) in line.indexed) {
      x[id] = i * BoardSizes.columnStep - width / 2;
      result[id] = (x[id]!, r * BoardSizes.rowStep);
    }
  }
  return result;
}

/// How strongly a dragged person's family follows them (spec 5.3: a small
/// drag moves only them; far, the family follows): 0 under a box's width,
/// all of the way past three; [partner]s follow sooner.
double familyPull(double distance, {bool partner = false}) {
  final start = partner ? BoardSizes.boxWidth * 0.25 : BoardSizes.boxWidth;
  final full = partner ? BoardSizes.boxWidth * 1.25 : BoardSizes.boxWidth * 3;
  return ((distance - start) / (full - start)).clamp(0.0, 1.0);
}
