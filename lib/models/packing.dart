/// Packing lists (Round 94): lists like "Ski trip" or "Beach",
/// each with its own sections (Round 95: set up in edit mode, for that
/// trip) and its things under them. A new list starts with the default
/// sections (Documents, Clothes, …), which the user can change. Not tied to
/// Dates or anything else.
class PackingSection {
  final String id;
  final String name;

  const PackingSection({required this.id, required this.name});

  PackingSection copyWith({String? name}) =>
      PackingSection(id: id, name: name ?? this.name);

  Map<String, dynamic> toJson() => {'id': id, 'name': name};

  factory PackingSection.fromJson(Map<String, dynamic> json) => PackingSection(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is PackingSection && other.id == id && other.name == name;

  @override
  int get hashCode => Object.hash(id, name);
}

/// One thing to pack: its name, how many (a count, 1 by default), and
/// whether it's packed (ticked).
class PackingItem {
  final String id;
  final String name;
  final String sectionId;
  final int count;
  final bool packed;

  /// The most a count goes to.
  static const maxCount = 99;

  const PackingItem({
    required this.id,
    required this.name,
    required this.sectionId,
    this.count = 1,
    this.packed = false,
  });

  PackingItem copyWith({
    String? id,
    String? name,
    String? sectionId,
    int? count,
    bool? packed,
  }) =>
      PackingItem(
        id: id ?? this.id,
        name: name ?? this.name,
        sectionId: sectionId ?? this.sectionId,
        count: count ?? this.count,
        packed: packed ?? this.packed,
      );

  /// A count of 1 and not packed aren't written.
  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'section': sectionId,
        if (count != 1) 'count': count,
        if (packed) 'packed': true,
      };

  factory PackingItem.fromJson(Map<String, dynamic> json) => PackingItem(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        sectionId: json['section'] as String? ?? '',
        count: ((json['count'] as num?)?.toInt() ?? 1).clamp(1, maxCount),
        packed: json['packed'] as bool? ?? false,
      );

  @override
  bool operator ==(Object other) =>
      other is PackingItem &&
      other.id == id &&
      other.name == name &&
      other.sectionId == sectionId &&
      other.count == count &&
      other.packed == packed;

  @override
  int get hashCode => Object.hash(id, name, sectionId, count, packed);
}

/// A packing list: a name, its sections in order (always at least one,
/// The user) and its things, in the user's order (shown grouped by
/// section).
class PackingList {
  final String id;
  final String name;
  final List<PackingSection> sections;
  final List<PackingItem> items;

  PackingList({
    required this.id,
    required this.name,
    required List<PackingSection> sections,
    List<PackingItem> items = const [],
  })  : sections = List.unmodifiable(sections),
        items = List.unmodifiable(items);

  /// Nothing put in it (a new list left so isn't kept).
  bool get isEmpty => name.trim().isEmpty && items.isEmpty;

  int get packedCount => items.where((i) => i.packed).length;

  PackingList copyWith({
    String? id,
    String? name,
    List<PackingSection>? sections,
    List<PackingItem>? items,
  }) =>
      PackingList(
        id: id ?? this.id,
        name: name ?? this.name,
        sections: sections ?? this.sections,
        items: items ?? this.items,
      );

  PackingSection? section(String id) =>
      sections.where((s) => s.id == id).firstOrNull;

  /// The section already called [name] (any case), if any.
  PackingSection? sectionNamed(String name, {String? except}) {
    final key = name.trim().toLowerCase();
    return sections
        .where((s) => s.id != except && s.name.trim().toLowerCase() == key)
        .firstOrNull;
  }

  /// [itemId] ticked if it wasn't, unticked if it was.
  PackingList toggled(String itemId) => copyWith(items: [
        for (final i in items)
          if (i.id == itemId) i.copyWith(packed: !i.packed) else i,
      ]);

  /// Everything unticked (Reset).
  PackingList reset() =>
      copyWith(items: [for (final i in items) i.copyWith(packed: false)]);

  /// The thing in [sectionId] already called [name] (any case), if any.
  PackingItem? named(String name, String sectionId, {String? except}) {
    final key = name.trim().toLowerCase();
    return items
        .where((i) =>
            i.id != except &&
            i.sectionId == sectionId &&
            i.name.trim().toLowerCase() == key)
        .firstOrNull;
  }

  /// Its things under its sections, every section (one set up in
  /// edit mode shows in view mode too, empty or not); a thing whose
  /// section isn't there goes under the last.
  List<(PackingSection, List<PackingItem>)> grouped() {
    final known = {for (final s in sections) s.id};
    return [
      for (final s in sections)
        (
          s,
          [
            for (final i in items)
              if (i.sectionId == s.id ||
                  (s == sections.last && !known.contains(i.sectionId)))
                i,
          ],
        ),
    ];
  }

  /// Edit mode's rows, a heading then its things: the thing at row [from]
  /// dragged to row [to] (`ReorderableList.onReorder` semantics), taking
  /// the section of the heading above where it lands (the first, if above
  /// them all). Headings don't move this way.
  PackingList moved(int from, int to) {
    final rows = <Object>[
      for (final (section, inIt) in grouped()) ...[section, ...inIt],
    ];
    if (from < 0 || from >= rows.length || rows[from] is! PackingItem) {
      return this;
    }
    if (to > from) to--;
    rows.insert(to.clamp(0, rows.length - 1), rows.removeAt(from));
    var section = sections.first.id;
    final order = <PackingItem>[];
    for (final row in rows) {
      if (row is PackingSection) {
        section = row.id;
      } else if (row is PackingItem) {
        order.add(
            row.sectionId == section ? row : row.copyWith(sectionId: section));
      }
    }
    return copyWith(items: order);
  }

  /// Section [id] moved to [to] among the sections (Round 96: dragged,
  /// as Ingredients'), its things with it.
  PackingList sectionMovedTo(String id, int to) {
    final at = sections.indexWhere((s) => s.id == id);
    if (at == -1 || to < 0 || to >= sections.length || at == to) return this;
    final list = [...sections];
    list.insert(to, list.removeAt(at));
    return copyWith(sections: list);
  }

  /// Section [id] gone, and its things with it (asked first). The
  /// last one left stays: a list has at least one.
  PackingList withoutSection(String id) {
    if (sections.length <= 1) return this;
    final gone = grouped()
        .where((g) => g.$1.id == id)
        .expand((g) => g.$2)
        .map((i) => i.id)
        .toSet();
    return copyWith(
      sections: [
        for (final s in sections)
          if (s.id != id) s,
      ],
      items: [
        for (final i in items)
          if (!gone.contains(i.id)) i,
      ],
    );
  }

  /// Same contents (for Save or Discard).
  bool sameAs(PackingList other) =>
      other.name == name &&
      _same(other.sections, sections) &&
      _same(other.items, items);

  static bool _same<T>(List<T> a, List<T> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'sections': [for (final s in sections) s.toJson()],
        'items': [for (final i in items) i.toJson()],
      };

  /// Round 94's lists had no sections of their own: they get [shared]
  /// (the sections all lists shared then).
  factory PackingList.fromJson(
    Map<String, dynamic> json, {
    List<PackingSection> shared = const [],
  }) {
    final own = json['sections'] as List<dynamic>?;
    final sections = own == null
        ? shared
        : [
            for (final s in own)
              PackingSection.fromJson(s as Map<String, dynamic>),
          ];
    return PackingList(
      id: json['id'] as String,
      name: json['name'] as String? ?? '',
      sections: sections.isEmpty ? PackingBook.defaults : sections,
      items: [
        for (final i in json['items'] as List<dynamic>? ?? const [])
          PackingItem.fromJson(i as Map<String, dynamic>),
      ],
    );
  }
}

/// Everything Packing holds: the default sections a new list starts with
/// (Round 95; Round 94's shared ones) and the lists, in the user's order.
class PackingBook {
  final List<PackingSection> sections;
  final List<PackingList> lists;

  PackingBook({
    required List<PackingSection> sections,
    List<PackingList> lists = const [],
  })  : sections = List.unmodifiable(sections.isEmpty ? defaults : sections),
        lists = List.unmodifiable(lists);

  /// The user's (Round 94): the usual sections.
  static const defaults = [
    PackingSection(id: 'documents', name: 'Documents'),
    PackingSection(id: 'clothes', name: 'Clothes'),
    PackingSection(id: 'toiletries', name: 'Toiletries'),
    PackingSection(id: 'electronics', name: 'Electronics'),
    PackingSection(id: 'medicine', name: 'Medicine'),
    PackingSection(id: 'other', name: 'Other'),
  ];

  /// The usual sections, and no lists yet.
  static final initial = PackingBook(sections: defaults);

  PackingList? byId(String id) => lists.where((l) => l.id == id).firstOrNull;

  PackingSection? section(String id) =>
      sections.where((s) => s.id == id).firstOrNull;

  /// The default section already called [name] (any case), if any.
  PackingSection? sectionNamed(String name, {String? except}) {
    final key = name.trim().toLowerCase();
    return sections
        .where((s) => s.id != except && s.name.trim().toLowerCase() == key)
        .firstOrNull;
  }

  PackingBook copyWith({
    List<PackingSection>? sections,
    List<PackingList>? lists,
  }) =>
      PackingBook(
        sections: sections ?? this.sections,
        lists: lists ?? this.lists,
      );

  /// [list] in place of the one with its id (nothing if it's gone).
  PackingBook withList(PackingList list) => copyWith(lists: [
        for (final l in lists)
          if (l.id == list.id) list else l,
      ]);

  Map<String, dynamic> toJson() => {
        'sections': [for (final s in sections) s.toJson()],
        'lists': [for (final l in lists) l.toJson()],
      };

  /// No sections stored: the usual ones. A list without its own sections
  /// (Round 94's) gets the ones stored here.
  factory PackingBook.fromJson(Map<String, dynamic> json) {
    final stored = json['sections'] as List<dynamic>?;
    final sections = stored == null
        ? defaults
        : [
            for (final s in stored)
              PackingSection.fromJson(s as Map<String, dynamic>),
          ];
    return PackingBook(
      sections: sections,
      lists: [
        for (final l in json['lists'] as List<dynamic>? ?? const [])
          PackingList.fromJson(l as Map<String, dynamic>,
              shared: sections.isEmpty ? defaults : sections),
      ],
    );
  }
}
