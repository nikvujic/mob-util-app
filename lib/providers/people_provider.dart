import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/people.dart';
import 'package:the_app/models/people_layout.dart';
import 'package:the_app/providers/dates_provider.dart';

/// People (Round 108), saved to `people.json`. A person's birthday lives
/// on the Dates page too (spec 6): kept in step from here, the date's
/// title, day, month, year and type being the person's.
class PeopleNotifier extends StateNotifier<PeopleBook> {
  PeopleNotifier(this._ref, AppStorage storage) : super(storage.initialPeople) {
    addListener(storage.savePeople, fireImmediately: false);
  }

  final Ref _ref;

  DatesNotifier get _dates => _ref.read(datesProvider.notifier);

  Person? byId(String id) => state.byId(id);

  /// A new person (not kept until [save]d) at [x], [y].
  Person draft({double x = 0, double y = 0}) =>
      Person(id: generateId(), name: '', x: x, y: y);

  /// [person] as it is now (added if new), their birthday's date in step.
  void save(Person person) {
    final synced = _syncDate(person);
    final known = state.byId(person.id) != null;
    state = state.copyWith(people: [
      for (final p in state.people)
        if (p.id == person.id) synced else p,
      if (!known) synced,
    ]);
  }

  /// The person's birthday on the Dates page: made, changed, or gone with
  /// it (the date's reminders and note stay its own).
  Person _syncDate(Person person) {
    final birthday = person.birthday;
    final dateId = person.dateId;
    final existing =
        dateId == null ? null : _ref.read(datesProvider).byId(dateId);
    // None, or kept out of Dates (Round 113): no date for it there.
    if (birthday == null || !person.inDates) {
      if (existing != null) _dates.delete(existing.id);
      return dateId == null ? person : person.copyWith(dateId: () => null);
    }
    final date = (existing ??
            DateEntry(
              id: generateId(),
              title: '',
              type: DateType.birthday,
              day: birthday.day,
              month: birthday.month,
              // Round 109: reminded as a birthday made in Dates is.
              reminders: DateReminder.defaults,
            ))
        .copyWith(
      title: person.name.trim(),
      type: DateType.birthday,
      day: birthday.day,
      month: birthday.month,
      year: () => birthday.year,
      yearly: true,
      personId: () => person.id,
    );
    _dates.save(date);
    return date.id == dateId ? person : person.copyWith(dateId: () => date.id);
  }

  /// Birthdays on the Dates page not yet anyone's, to take over.
  List<DateEntry> freeBirthdays() => [
        for (final d in _ref.read(datesProvider).dates)
          if (d.type == DateType.birthday && d.personId == null) d,
      ];

  /// [person]'s birthday set from the birthday [dateId] on the Dates
  /// page (Round 113: only its day, month and year are taken; the
  /// original stays as it was, theirs to delete if they like). Shown in
  /// Dates, it's their own date there, as one set by hand.
  Person takeBirthday(Person person, String dateId) {
    final date = _ref.read(datesProvider).byId(dateId);
    if (date == null) return person;
    save(person.copyWith(
      birthday: () =>
          PersonDate(day: date.day, month: date.month, year: date.year),
    ));
    return state.byId(person.id)!;
  }

  /// Removes [id], their relations and their birthday's date; returns
  /// what Undo needs.
  ({PeopleBook book, DateEntry? date}) remove(String id) {
    final before = state;
    final person = state.byId(id);
    final dateId = person?.dateId;
    final date = dateId == null ? null : _ref.read(datesProvider).byId(dateId);
    if (date != null) _dates.delete(date.id);
    state = state.without(id);
    return (book: before, date: date);
  }

  void undoRemove(({PeopleBook book, DateEntry? date}) removed) {
    state = removed.book;
    if (removed.date case final date?) _dates.save(date);
  }

  /// Relates [from] and [to] as [kind] (for a parent: [from] is [to]'s);
  /// returns why not, or null when done. [bring] (the one just picked;
  /// [to] by default) comes next to the other if far.
  String? relate(
    RelationKind kind,
    String from,
    String to, {
    bool former = false,
    String label = '',
    String? bring,
  }) {
    lastAlso = const [];
    final why = state.whyNot(kind, from, to);
    if (why != null) return why;
    state = state.copyWith(relations: [
      ...state.relations,
      Relation(
        id: generateId(),
        kind: kind,
        from: from,
        to: to,
        former: kind == RelationKind.partner && former,
        label: kind == RelationKind.other ? label.trim() : '',
      ),
    ]);
    final moved = bring == from ? from : to;
    _nearEachOther(moved == from ? to : from, moved);
    _alsoRelate(kind, from, to);
    return null;
  }

  /// Who [relate] related as well, the last time (Round 114), to say so.
  List<String> lastAlso = const [];

  /// Round 114: what follows from it. A parent's child's brothers and
  /// sisters are their children too; a new brother or sister shares the
  /// other's parents. Each only where it makes sense (two parents at
  /// most, nobody their own ancestor); nobody moves.
  void _alsoRelate(RelationKind kind, String from, String to) {
    final pairs = <(String, String)>[
      if (kind == RelationKind.parent)
        for (final s in _siblingsOf(to)) (from, s),
      if (kind == RelationKind.sibling) ...[
        for (final p in state.parentsOf(from)) (p, to),
        for (final p in state.parentsOf(to)) (p, from),
      ],
    ];
    final also = <String>[];
    for (final (parent, child) in pairs) {
      if (state.whyNot(RelationKind.parent, parent, child) != null) continue;
      state = state.copyWith(relations: [
        ...state.relations,
        Relation(
            id: generateId(),
            kind: RelationKind.parent,
            from: parent,
            to: child),
      ]);
      also.add(kind == RelationKind.parent ? child : parent);
    }
    lastAlso = also;
  }

  /// Brothers and sisters: by a sibling relation, or a shared parent.
  Set<String> _siblingsOf(String id) => {
        for (final r in state.relations)
          if (r.kind == RelationKind.sibling && r.involves(id)) r.otherThan(id),
        for (final p in state.parentsOf(id))
          for (final c in state.childrenOf(p))
            if (c != id) c,
      };

  /// Spec 5.4: when a relation is added, the newly linked person [b]
  /// comes next to [a] if they're far apart; nobody else moves.
  void _nearEachOther(String a, String b) {
    final pa = state.byId(a), pb = state.byId(b);
    if (pa == null || pb == null) return;
    final dx = pb.x - pa.x, dy = pb.y - pa.y;
    if (dx.abs() < BoardSizes.columnStep * 3 &&
        dy.abs() < BoardSizes.rowStep * 2) {
      return;
    }
    final relation = state.relations.last;
    final (x, y) = switch (relation.kind) {
      // A child goes under the parent, a parent over the child.
      RelationKind.parent when relation.to == b => (
          pa.x,
          pa.y + BoardSizes.rowStep
        ),
      RelationKind.parent => (pa.x, pa.y - BoardSizes.rowStep),
      _ => (pa.x + BoardSizes.columnStep, pa.y),
    };
    move({b: (x, y)});
  }

  void unrelate(String relationId) {
    state = state.copyWith(relations: [
      for (final r in state.relations)
        if (r.id != relationId) r,
    ]);
  }

  /// People moved on the board: each id to its new middle.
  void move(Map<String, (double, double)> to) {
    if (to.isEmpty) return;
    state = state.copyWith(people: [
      for (final p in state.people)
        if (to[p.id] case (final x, final y)) p.copyWith(x: x, y: y) else p,
    ]);
  }

  void setView(BoardView view) => state = state.copyWith(view: view);

  /// Everyone into the default layout (spec 5.4); returns where they
  /// were, for Undo ([move] puts them back).
  Map<String, (double, double)> tidy() {
    final before = {for (final p in state.people) p.id: (p.x, p.y)};
    move(tidyLayout(state));
    return before;
  }

  /// Round 109: [id] the main person (null: none).
  void setMain(String? id) => state = state.copyWith(mainId: () => id);

  void setHighlightFamily(bool on) =>
      state = state.copyWith(highlightFamily: on);

  void replaceAll(PeopleBook book) => state = book;
}

final peopleProvider = StateNotifierProvider<PeopleNotifier, PeopleBook>(
  (ref) => PeopleNotifier(ref, ref.watch(appStorageProvider)),
);
