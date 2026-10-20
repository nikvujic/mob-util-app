/// Packing lists (Round 94, Nikola): lists like "Ski trip" or "Beach",
/// each with its items under sections. The sections (Documents, Clothes,
/// …) are shared by all lists, set up once; Other is always there, last.
/// Not tied to Dates or anything else.
class PackingSection {
  final String id;
  final String name;

  const PackingSection({required this.id, required this.name});

  /// Other's id: always in the book, always last; items whose section is
  /// gone go there.
  static const otherId = 'other';

  static const other = PackingSection(id: otherId, name: 'Other');

  bool get isOther => id == otherId;

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
        sectionId: json['section'] as String? ?? PackingSection.otherId,
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

/// A packing list: a name and its items, in the user's order (shown
/// grouped by section, in the sections' order).
class PackingList {
  final String id;
  final String name;
  final List<PackingItem> items;

  PackingList({
    required this.id,
    required this.name,
    List<PackingItem> items = const [],
  }) : items = List.unmodifiable(items);

  /// Nothing in it at all (a new list left so is dropped).
  bool get isEmpty => name.trim().isEmpty && items.isEmpty;

  int get packedCount => items.where((i) => i.packed).length;

  PackingList copyWith({String? id, String? name, List<PackingItem>? items}) =>
      PackingList(
        id: id ?? this.id,
        name: name ?? this.name,
        items: items ?? this.items,
      );

  /// [itemId] ticked if it wasn't, unticked if it was.
  PackingList toggled(String itemId) => copyWith(items: [
        for (final i in items)
          if (i.id == itemId) i.copyWith(packed: !i.packed) else i,
      ]);

  /// Everything unticked (Reset).
  PackingList reset() =>
      copyWith(items: [for (final i in items) i.copyWith(packed: false)]);

  /// The item in [sectionId] already called [name] (any case), if any.
  PackingItem? named(String name, String sectionId, {String? except}) {
    final key = name.trim().toLowerCase();
    return items
        .where((i) =>
            i.id != except &&
            i.sectionId == sectionId &&
            i.name.trim().toLowerCase() == key)
        .firstOrNull;
  }

  /// Its items under [sections], in their order; an item whose section
  /// isn't there goes under Other. Sections with no items are left out
  /// unless [keepEmpty].
  List<(PackingSection, List<PackingItem>)> grouped(
    List<PackingSection> sections, {
    bool keepEmpty = false,
  }) {
    final known = {for (final s in sections) s.id};
    return [
      for (final s in sections)
        if ([
          for (final i in items)
            if (i.sectionId == s.id ||
                (s.isOther && !known.contains(i.sectionId)))
              i,
        ]
            case final inIt when keepEmpty || inIt.isNotEmpty)
          (s, inIt),
    ];
  }

  /// Edit mode's rows, a heading then its items, every section shown
  /// ([grouped] with the empty ones): the item at row [from] dragged to
  /// row [to] (`ReorderableList.onReorder` semantics), taking the section
  /// of the heading above where it lands (the first, if above them all).
  PackingList moved(List<PackingSection> sections, int from, int to) {
    final rows = <Object>[
      for (final (section, inIt) in grouped(sections, keepEmpty: true)) ...[
        section,
        ...inIt,
      ],
    ];
    if (from < 0 || from >= rows.length || rows[from] is! PackingItem) {
      return this;
    }
    if (to > from) to--;
    rows.insert(to.clamp(0, rows.length - 1), rows.removeAt(from));
    var section = sections.isEmpty ? PackingSection.otherId : sections.first.id;
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

  /// Same contents (for Discard changes).
  bool sameAs(PackingList other) =>
      other.name == name &&
      other.items.length == items.length &&
      [
        for (var i = 0; i < items.length; i++) other.items[i] == items[i],
      ].every((same) => same);

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'items': [for (final i in items) i.toJson()],
      };

  factory PackingList.fromJson(Map<String, dynamic> json) => PackingList(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        items: [
          for (final i in json['items'] as List<dynamic>? ?? const [])
            PackingItem.fromJson(i as Map<String, dynamic>),
        ],
      );
}

/// Everything Packing holds: the sections every list shares (Other always
/// last) and the lists, in the user's order.
class PackingBook {
  final List<PackingSection> sections;
  final List<PackingList> lists;

  /// Other is put last if it's elsewhere, and added if it's missing.
  PackingBook({
    required List<PackingSection> sections,
    List<PackingList> lists = const [],
  })  : sections = List.unmodifiable([
          for (final s in sections)
            if (!s.isOther) s,
          sections.where((s) => s.isOther).firstOrNull ?? PackingSection.other,
        ]),
        lists = List.unmodifiable(lists);

  /// Nikola's (Round 94): the usual sections, and no lists yet.
  static final initial = PackingBook(sections: const [
    PackingSection(id: 'documents', name: 'Documents'),
    PackingSection(id: 'clothes', name: 'Clothes'),
    PackingSection(id: 'toiletries', name: 'Toiletries'),
    PackingSection(id: 'electronics', name: 'Electronics'),
    PackingSection(id: 'medicine', name: 'Medicine'),
    PackingSection.other,
  ]);

  PackingList? byId(String id) => lists.where((l) => l.id == id).firstOrNull;

  PackingSection? section(String id) =>
      sections.where((s) => s.id == id).firstOrNull;

  /// The section already called [name] (any case), if any.
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

  /// Section [id] gone; its items, in every list, go to Other. Other
  /// itself stays.
  PackingBook withoutSection(String id) {
    if (id == PackingSection.otherId) return this;
    return PackingBook(
      sections: [
        for (final s in sections)
          if (s.id != id) s,
      ],
      lists: [
        for (final l in lists)
          l.copyWith(items: [
            for (final i in l.items)
              i.sectionId == id
                  ? i.copyWith(sectionId: PackingSection.otherId)
                  : i,
          ]),
      ],
    );
  }

  /// How many items, over all lists, are in section [id].
  int itemsIn(String id) => lists.fold(
      0, (n, l) => n + l.items.where((i) => i.sectionId == id).length);

  Map<String, dynamic> toJson() => {
        'sections': [for (final s in sections) s.toJson()],
        'lists': [for (final l in lists) l.toJson()],
      };

  /// No sections stored (none written yet): the usual ones.
  factory PackingBook.fromJson(Map<String, dynamic> json) {
    final sections = json['sections'] as List<dynamic>?;
    return PackingBook(
      sections: sections == null
          ? initial.sections
          : [
              for (final s in sections)
                PackingSection.fromJson(s as Map<String, dynamic>),
            ],
      lists: [
        for (final l in json['lists'] as List<dynamic>? ?? const [])
          PackingList.fromJson(l as Map<String, dynamic>),
      ],
    );
  }
}
