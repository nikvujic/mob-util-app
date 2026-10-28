/// People (Round 108, spec `docs/PEOPLE_SPEC.md`): the people you know
/// as boxes on a board, with relations that make family trees. A person's
/// birthday may be tied to a date on the Dates page ([Person.dateId]).
enum Gender {
  male('Male'),
  female('Female');

  final String label;

  const Gender(this.label);

  static Gender fromId(String? id) =>
      values.where((g) => g.name == id).firstOrNull ?? Gender.male;
}

/// The avatar's age (spec 4.2), from the age in years.
enum AgeGroup {
  baby('Baby', 0),
  kid('Kid', 3),
  teen('Teen', 13),
  adult('Adult', 20),
  olderAdult('Older adult', 40),
  older('Older', 60),
  old('Old', 80);

  final String label;

  /// The age it starts at.
  final int from;

  const AgeGroup(this.label, this.from);

  /// The group for [age] in years; none known: an adult.
  static AgeGroup of(int? age) {
    if (age == null) return adult;
    return values.lastWhere((g) => age >= g.from, orElse: () => baby);
  }
}

/// A day of the year, and its year if known (a birthday) or needed (a
/// date of death has one).
class PersonDate {
  final int day;
  final int month;
  final int? year;

  const PersonDate({required this.day, required this.month, this.year});

  Map<String, dynamic> toJson() => {
        'day': day,
        'month': month,
        if (year != null) 'year': year,
      };

  factory PersonDate.fromJson(Map<String, dynamic> json) => PersonDate(
        day: (json['day'] as num).toInt(),
        month: (json['month'] as num).toInt(),
        year: (json['year'] as num?)?.toInt(),
      );

  /// Whole years from this date (with its year) to [at]; null without a
  /// year.
  int? yearsTo(DateTime at) {
    final y = year;
    if (y == null) return null;
    final before = at.month < month || (at.month == month && at.day < day);
    return at.year - y - (before ? 1 : 0);
  }

  @override
  bool operator ==(Object other) =>
      other is PersonDate &&
      other.day == day &&
      other.month == month &&
      other.year == year;

  @override
  int get hashCode => Object.hash(day, month, year);
}

class Person {
  final String id;

  /// The full name.
  final String name;
  final Gender gender;
  final PersonDate? birthday;

  /// Deceased, and when (spec 2: the year at least, so the age stops).
  final bool deceased;
  final PersonDate? diedOn;

  /// Important people stand out on the board.
  final bool highlighted;
  final String note;

  /// The box's middle on the board, in board units.
  final double x;
  final double y;

  /// The birthday's date on the Dates page (spec 6), if it has one.
  final String? dateId;

  /// Round 113: their birthday shown in Dates (a projection, for the
  /// overview and its reminders); off, People keeps it to itself.
  final bool inDates;

  const Person({
    required this.id,
    required this.name,
    this.gender = Gender.male,
    this.birthday,
    this.deceased = false,
    this.diedOn,
    this.highlighted = false,
    this.note = '',
    this.x = 0,
    this.y = 0,
    this.dateId,
    this.inDates = true,
  });

  /// Their age now (or when they died), in years; null if their birth
  /// year isn't known.
  int? ageAt(DateTime now) {
    final died = diedOn;
    if (deceased && died?.year != null) {
      return birthday
          ?.yearsTo(DateTime(died!.year!, died.month, died.day.clamp(1, 28)));
    }
    return birthday?.yearsTo(now);
  }

  AgeGroup ageGroupAt(DateTime now) => AgeGroup.of(ageAt(now));

  Person copyWith({
    String? name,
    Gender? gender,
    PersonDate? Function()? birthday,
    bool? deceased,
    PersonDate? Function()? diedOn,
    bool? highlighted,
    String? note,
    double? x,
    double? y,
    String? Function()? dateId,
    bool? inDates,
  }) =>
      Person(
        id: id,
        name: name ?? this.name,
        gender: gender ?? this.gender,
        birthday: birthday == null ? this.birthday : birthday(),
        deceased: deceased ?? this.deceased,
        diedOn: diedOn == null ? this.diedOn : diedOn(),
        highlighted: highlighted ?? this.highlighted,
        note: note ?? this.note,
        x: x ?? this.x,
        y: y ?? this.y,
        dateId: dateId == null ? this.dateId : dateId(),
        inDates: inDates ?? this.inDates,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'gender': gender.name,
        if (birthday != null) 'birthday': birthday!.toJson(),
        if (deceased) 'deceased': true,
        if (diedOn != null) 'diedOn': diedOn!.toJson(),
        if (highlighted) 'highlighted': true,
        if (note.isNotEmpty) 'note': note,
        'x': x,
        'y': y,
        if (dateId != null) 'dateId': dateId,
        if (!inDates) 'inDates': false,
      };

  factory Person.fromJson(Map<String, dynamic> json) => Person(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        gender: Gender.fromId(json['gender'] as String?),
        birthday: json['birthday'] == null
            ? null
            : PersonDate.fromJson(json['birthday'] as Map<String, dynamic>),
        deceased: json['deceased'] as bool? ?? false,
        diedOn: json['diedOn'] == null
            ? null
            : PersonDate.fromJson(json['diedOn'] as Map<String, dynamic>),
        highlighted: json['highlighted'] as bool? ?? false,
        note: json['note'] as String? ?? '',
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        dateId: json['dateId'] as String?,
        inDates: json['inDates'] as bool? ?? true,
      );
}

/// What a relation is (spec 5.1). [parent]: `from` is `to`'s parent.
enum RelationKind {
  parent,
  partner,
  sibling,
  other;

  static RelationKind? fromId(String? id) =>
      values.where((k) => k.name == id).firstOrNull;

  /// A family tie: pulls on the board and counts for Tidy (not [other]).
  bool get family => this != other;
}

class Relation {
  final String id;
  final RelationKind kind;
  final String from;
  final String to;

  /// A partner no more (drawn dashed).
  final bool former;

  /// An [RelationKind.other]'s word ("Godfather"), or empty.
  final String label;

  const Relation({
    required this.id,
    required this.kind,
    required this.from,
    required this.to,
    this.former = false,
    this.label = '',
  });

  bool involves(String id) => from == id || to == id;

  /// The other end from [id].
  String otherThan(String id) => from == id ? to : from;

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        'from': from,
        'to': to,
        if (former) 'former': true,
        if (label.isNotEmpty) 'label': label,
      };

  /// Null for a kind this version doesn't know (dropped).
  static Relation? fromJson(Map<String, dynamic> json) {
    final kind = RelationKind.fromId(json['kind'] as String?);
    if (kind == null) return null;
    return Relation(
      id: json['id'] as String,
      kind: kind,
      from: json['from'] as String,
      to: json['to'] as String,
      former: json['former'] as bool? ?? false,
      label: json['label'] as String? ?? '',
    );
  }
}

/// Where the board was looking: its middle (board units) and zoom.
class BoardView {
  final double x;
  final double y;
  final double zoom;

  static const minZoom = 0.25;
  static const maxZoom = 2.0;

  const BoardView({this.x = 0, this.y = 0, this.zoom = 1});

  Map<String, dynamic> toJson() => {'x': x, 'y': y, 'zoom': zoom};

  factory BoardView.fromJson(Map<String, dynamic> json) => BoardView(
        x: (json['x'] as num?)?.toDouble() ?? 0,
        y: (json['y'] as num?)?.toDouble() ?? 0,
        zoom: ((json['zoom'] as num?)?.toDouble() ?? 1).clamp(minZoom, maxZoom),
      );
}

/// Everyone, how they're related, and where the board was looking.
class PeopleBook {
  final List<Person> people;
  final List<Relation> relations;
  final BoardView view;

  /// Round 109: the main person (the board can centre on them; their
  /// family can be highlighted), if one is set.
  final String? mainId;

  /// Everyone in the main person's family highlighted on the board.
  final bool highlightFamily;

  const PeopleBook._(this.people, this.relations, this.view)
      : mainId = null,
        highlightFamily = false;

  PeopleBook({
    List<Person> people = const [],
    List<Relation> relations = const [],
    this.view = const BoardView(),
    this.mainId,
    this.highlightFamily = false,
  })  : people = List.unmodifiable(people),
        relations = List.unmodifiable(relations);

  static const empty = PeopleBook._([], [], BoardView());

  /// The main person, if set and still here.
  Person? get main => mainId == null ? null : byId(mainId!);

  /// Who the family highlight shows: the main person's family (all tied
  /// to them by family relations), when it's on.
  Set<String> get familyShown =>
      highlightFamily && main != null ? familyOf(mainId!) : const {};

  /// Whether a sibling relation [r] gets its own line on the board
  /// (Round 115): not with a parent in common, whose line to their
  /// children already joins them.
  bool drawsSiblingBar(Relation r) =>
      r.kind == RelationKind.sibling &&
      !parentsOf(r.from).any(parentsOf(r.to).contains);

  Person? byId(String id) => people.where((p) => p.id == id).firstOrNull;

  PeopleBook copyWith({
    List<Person>? people,
    List<Relation>? relations,
    BoardView? view,
    String? Function()? mainId,
    bool? highlightFamily,
  }) =>
      PeopleBook(
        people: people ?? this.people,
        relations: relations ?? this.relations,
        view: view ?? this.view,
        mainId: mainId == null ? this.mainId : mainId(),
        highlightFamily: highlightFamily ?? this.highlightFamily,
      );

  /// [id]'s relations.
  Iterable<Relation> of(String id) => relations.where((r) => r.involves(id));

  List<String> parentsOf(String id) => [
        for (final r in relations)
          if (r.kind == RelationKind.parent && r.to == id) r.from,
      ];

  List<String> childrenOf(String id) => [
        for (final r in relations)
          if (r.kind == RelationKind.parent && r.from == id) r.to,
      ];

  List<String> partnersOf(String id) => [
        for (final r in relations)
          if (r.kind == RelationKind.partner && r.involves(id)) r.otherThan(id),
      ];

  /// Whether [a] is [b]'s ancestor (a parent, or a parent's ancestor).
  bool isAncestor(String a, String b) {
    final seen = <String>{};
    final queue = [...parentsOf(b)];
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      if (p == a) return true;
      if (seen.add(p)) queue.addAll(parentsOf(p));
    }
    return false;
  }

  /// Why [kind] from [from] to [to] can't be (spec 5.1), or null if it can.
  String? whyNot(RelationKind kind, String from, String to) {
    if (from == to) return "Someone can't be related to themselves";
    if (relations.any((r) => r.involves(from) && r.involves(to))) {
      return 'They are already related';
    }
    if (kind == RelationKind.parent) {
      if (parentsOf(to).length >= 2) return 'They already have two parents';
      if (isAncestor(to, from)) {
        return "Someone can't be their own ancestor";
      }
    }
    return null;
  }

  /// Everyone tied to [id] by family relations, [id] too (spec 5.3).
  Set<String> familyOf(String id) {
    final seen = <String>{id};
    final queue = [id];
    while (queue.isNotEmpty) {
      final p = queue.removeLast();
      for (final r in relations) {
        if (r.kind.family && r.involves(p)) {
          final o = r.otherThan(p);
          if (seen.add(o)) queue.add(o);
        }
      }
    }
    return seen;
  }

  /// Without [id], and their relations (and not main any more).
  PeopleBook without(String id) => copyWith(
        mainId: mainId == id ? () => null : null,
        people: [
          for (final p in people)
            if (p.id != id) p,
        ],
        relations: [
          for (final r in relations)
            if (!r.involves(id)) r,
        ],
      );

  Map<String, dynamic> toJson() => {
        'people': [for (final p in people) p.toJson()],
        'relations': [for (final r in relations) r.toJson()],
        'view': view.toJson(),
        if (mainId != null) 'main': mainId,
        if (highlightFamily) 'highlightFamily': true,
      };

  /// Relations whose people aren't there are dropped.
  factory PeopleBook.fromJson(Map<String, dynamic> json) {
    final people = [
      for (final p in json['people'] as List<dynamic>? ?? const [])
        Person.fromJson(p as Map<String, dynamic>),
    ];
    final ids = {for (final p in people) p.id};
    return PeopleBook(
      people: people,
      relations: [
        for (final r in json['relations'] as List<dynamic>? ?? const [])
          if (Relation.fromJson(r as Map<String, dynamic>) case final rel?
              when ids.contains(rel.from) && ids.contains(rel.to))
            rel,
      ],
      view: json['view'] == null
          ? const BoardView()
          : BoardView.fromJson(json['view'] as Map<String, dynamic>),
      mainId: ids.contains(json['main']) ? json['main'] as String : null,
      highlightFamily: json['highlightFamily'] as bool? ?? false,
    );
  }
}
