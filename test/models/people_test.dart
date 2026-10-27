import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/people.dart';
import 'package:the_app/models/people_layout.dart';

/// People (Round 108): ages, relations' rules, families, Tidy, the pull.
void main() {
  Person person(String id,
          {int? born,
          Gender gender = Gender.male,
          double x = 0,
          double y = 0}) =>
      Person(
        id: id,
        name: id,
        gender: gender,
        birthday:
            born == null ? null : PersonDate(day: 1, month: 6, year: born),
        x: x,
        y: y,
      );

  Relation rel(String id, RelationKind kind, String from, String to) =>
      Relation(id: id, kind: kind, from: from, to: to);

  group('ages', () {
    test('the avatar by age: each group from its first year', () {
      expect(AgeGroup.of(null), AgeGroup.adult, reason: 'unknown');
      for (final (age, group) in [
        (0, AgeGroup.baby),
        (2, AgeGroup.baby),
        (3, AgeGroup.kid),
        (12, AgeGroup.kid),
        (13, AgeGroup.teen),
        (19, AgeGroup.teen),
        (20, AgeGroup.adult),
        (39, AgeGroup.adult),
        (40, AgeGroup.olderAdult),
        (59, AgeGroup.olderAdult),
        (60, AgeGroup.older),
        (79, AgeGroup.older),
        (80, AgeGroup.old),
        (104, AgeGroup.old),
      ]) {
        expect(AgeGroup.of(age), group, reason: '$age');
      }
    });

    test('whole years, the birthday counted on the day', () {
      const b = PersonDate(day: 24, month: 10, year: 1995);
      expect(b.yearsTo(DateTime(2026, 10, 23)), 30);
      expect(b.yearsTo(DateTime(2026, 10, 24)), 31);
      expect(b.yearsTo(DateTime(2026, 11, 1)), 31);
      expect(
          const PersonDate(day: 1, month: 1).yearsTo(DateTime(2026)), isNull);
    });

    test('a deceased person: their age stops at their death', () {
      final p = Person(
        id: 'm',
        name: 'Mila',
        birthday: const PersonDate(day: 1, month: 9, year: 1931),
        deceased: true,
        diedOn: const PersonDate(day: 20, month: 5, year: 2015),
      );
      expect(p.ageAt(DateTime(2026, 10, 27)), 83);
      expect(p.ageGroupAt(DateTime(2026, 10, 27)), AgeGroup.old);
      // Marked deceased with no date: the age goes on.
      expect(p.copyWith(diedOn: () => null).ageAt(DateTime(2026, 10, 27)), 95);
    });
  });

  group('relations', () {
    final book = PeopleBook(
      people: [person('a'), person('b'), person('c'), person('d')],
      relations: [
        rel('1', RelationKind.parent, 'a', 'c'),
        rel('2', RelationKind.parent, 'b', 'c'),
        rel('3', RelationKind.partner, 'a', 'b'),
      ],
    );

    test('parents, children, partners', () {
      expect(book.parentsOf('c'), ['a', 'b']);
      expect(book.childrenOf('a'), ['c']);
      expect(book.partnersOf('b'), ['a']);
      expect(book.isAncestor('a', 'c'), isTrue);
      expect(book.isAncestor('c', 'a'), isFalse);
    });

    test("what can't be, and why", () {
      expect(book.whyNot(RelationKind.other, 'a', 'a'), isNotNull);
      expect(book.whyNot(RelationKind.sibling, 'a', 'c'),
          'They are already related');
      expect(book.whyNot(RelationKind.parent, 'd', 'c'),
          'They already have two parents');
      expect(book.whyNot(RelationKind.parent, 'c', 'd'), isNull);
      final deeper = book.copyWith(relations: [
        ...book.relations,
        rel('4', RelationKind.parent, 'c', 'd'),
      ]);
      expect(deeper.whyNot(RelationKind.parent, 'd', 'a'),
          "Someone can't be their own ancestor");
      expect(book.whyNot(RelationKind.partner, 'c', 'd'), isNull);
    });

    test('a family: everyone tied by family relations (not Other)', () {
      final withFriend = book.copyWith(relations: [
        ...book.relations,
        rel('4', RelationKind.other, 'a', 'd'),
      ]);
      expect(withFriend.familyOf('c'), {'a', 'b', 'c'});
      expect(withFriend.familyOf('d'), {'d'});
    });

    test('someone gone takes their relations with them', () {
      final left = book.without('a');
      expect(left.people.map((p) => p.id), ['b', 'c', 'd']);
      expect(left.relations.map((r) => r.id), ['2']);
    });

    test('read back as written; relations to nobody dropped', () {
      final again = PeopleBook.fromJson(book.toJson());
      expect(again.toJson(), book.toJson());
      final broken = PeopleBook.fromJson({
        'people': [person('a').toJson()],
        'relations': [rel('1', RelationKind.partner, 'a', 'gone').toJson()],
      });
      expect(broken.relations, isEmpty);
      expect(broken.view.zoom, 1);
    });
  });

  group('Tidy', () {
    // Grandparents g1+g2; their children p (with partner q) and s; p and
    // q's children k1 (born 2010) and k2 (born 2005); x on their own.
    final book = PeopleBook(
      people: [
        person('g1', born: 1940),
        person('g2', born: 1942),
        person('p', born: 1970),
        person('q', born: 1972),
        person('s', born: 1968),
        person('k1', born: 2010),
        person('k2', born: 2005),
        person('x'),
      ],
      relations: [
        rel('1', RelationKind.partner, 'g1', 'g2'),
        rel('2', RelationKind.parent, 'g1', 'p'),
        rel('3', RelationKind.parent, 'g2', 'p'),
        rel('4', RelationKind.parent, 'g1', 's'),
        rel('5', RelationKind.partner, 'p', 'q'),
        rel('6', RelationKind.parent, 'p', 'k1'),
        rel('7', RelationKind.parent, 'q', 'k1'),
        rel('8', RelationKind.parent, 'p', 'k2'),
        rel('9', RelationKind.parent, 'q', 'k2'),
      ],
    );

    test('generations: parents above children, partners level', () {
      final gen = generations(book, book.familyOf('p'));
      expect(gen, {
        'g1': 0,
        'g2': 0,
        'p': 1,
        'q': 1,
        's': 1,
        'k1': 2,
        'k2': 2,
      });
    });

    test(
        "a co-parent with no parents of their own (not a partner) sits just "
        'above their child, not up with the grandparents', () {
      final more = book.copyWith(people: [
        ...book.people,
        person('r'),
        person('k3', born: 2015),
      ], relations: [
        ...book.relations,
        rel('10', RelationKind.parent, 'p', 'k3'),
        rel('11', RelationKind.parent, 'r', 'k3'),
      ]);
      final gen = generations(more, more.familyOf('p'));
      expect(gen['r'], gen['p']);
      expect(gen['k3'], gen['p']! + 1);
    });

    test("a partner (either way round) on their partner's row", () {
      final more = book.copyWith(people: [
        ...book.people,
        person('t'),
      ], relations: [
        ...book.relations,
        rel('10', RelationKind.partner, 't', 's'),
      ]);
      final gen = generations(more, more.familyOf('s'));
      expect(gen['t'], gen['s']);
      expect(gen['s'], 1);
    });

    test(
        'rows by generation; partners side by side; children in birth '
        'order; no two in one place', () {
      final at = tidyLayout(book);
      double y(String id) => at[id]!.$2;
      double x(String id) => at[id]!.$1;
      expect(y('g1'), y('g2'));
      expect(y('p'), y('g1') + BoardSizes.rowStep);
      expect(y('k1'), y('p') + BoardSizes.rowStep);
      expect((x('p') - x('q')).abs(), BoardSizes.columnStep,
          reason: 'partners next to each other');
      expect(x('k2'), lessThan(x('k1')), reason: 'the elder first');
      final places = at.values.toSet();
      expect(places, hasLength(at.length));
    });

    test('someone with no family in a grid to the right', () {
      final at = tidyLayout(book);
      final family = book.familyOf('p');
      final right =
          family.map((id) => at[id]!.$1).reduce((a, b) => a > b ? a : b);
      expect(at['x']!.$1, greaterThan(right));
    });

    test('two families side by side, not on top of each other', () {
      final two = book.copyWith(people: [
        ...book.people,
        person('m'),
        person('n'),
      ], relations: [
        ...book.relations,
        rel('10', RelationKind.partner, 'm', 'n'),
      ]);
      final at = tidyLayout(two);
      final first = two.familyOf('p').map((id) => at[id]!.$1);
      final maxFirst = first.reduce((a, b) => a > b ? a : b);
      expect(at['m']!.$1, greaterThan(maxFirst));
      expect(at['n']!.$1, greaterThan(maxFirst));
    });
  });

  test('the pull: nothing for a small drag, all of it far', () {
    expect(familyPull(BoardSizes.boxWidth * 0.9), 0);
    expect(familyPull(BoardSizes.boxWidth * 2), closeTo(0.5, 1e-9));
    expect(familyPull(BoardSizes.boxWidth * 3), 1);
    expect(familyPull(BoardSizes.boxWidth * 10), 1);
    expect(familyPull(BoardSizes.boxWidth * 0.75, partner: true),
        closeTo(0.5, 1e-9));
    expect(familyPull(BoardSizes.boxWidth * 0.2, partner: true), 0,
        reason: 'fine-tuning');
  });

  test(
      'the main person (Round 109): kept, read back; their family shown '
      'only when on; gone with them', () {
    final book = PeopleBook(
      people: [person('a'), person('b'), person('c')],
      relations: [rel('1', RelationKind.parent, 'a', 'b')],
      mainId: 'b',
    );
    expect(book.main!.id, 'b');
    expect(book.familyShown, isEmpty, reason: 'off');
    final on = book.copyWith(highlightFamily: true);
    expect(on.familyShown, {'a', 'b'});
    final again = PeopleBook.fromJson(on.toJson());
    expect((again.mainId, again.highlightFamily), ('b', true));
    expect(on.without('b').mainId, isNull);
    expect(on.without('b').familyShown, isEmpty);
    expect(on.without('c').mainId, 'b');
  });
}
