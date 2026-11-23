import 'package:the_app/models/planner_task.dart';

/// What a document is (spec: types). Its [name] is stored; never renamed.
enum DocKind {
  document('Document'),
  receipt('Receipt'),
  barcode('Barcode'),
  ticket('Ticket');

  const DocKind(this.label);

  final String label;

  /// Whether creating one opens the camera at once.
  bool get startsWithCamera => this != document;

  /// Whether it has a barcode of its own (a crop of one of its pictures).
  bool get hasBarcode => this == barcode || this == ticket;

  static DocKind fromId(String? id) =>
      values.where((k) => k.name == id).firstOrNull ?? document;
}

/// How long before a date its reminder comes.
enum DocRemind {
  none('None', 0),
  week('A week before', 7),
  month('A month before', 30),
  threeMonths('Three months before', 91),
  sixMonths('Six months before', 182);

  const DocRemind(this.label, this.days);

  final String label;
  final int days;

  static DocRemind fromId(String? id) =>
      values.where((r) => r.name == id).firstOrNull ?? none;
}

/// One picture of a document: its file's id and how it's turned (quarter
/// turns clockwise, 0–3), applied where it's shown.
class DocPicture {
  final String id;
  final int turns;

  const DocPicture(this.id, {this.turns = 0});

  DocPicture turned() => DocPicture(id, turns: (turns + 1) % 4);

  Map<String, dynamic> toJson() => {
        'id': id,
        if (turns != 0) 'turns': turns,
      };

  factory DocPicture.fromJson(Map<String, dynamic> json) => DocPicture(
        json['id'] as String,
        turns: ((json['turns'] as num?)?.toInt() ?? 0) % 4,
      );

  @override
  bool operator ==(Object other) =>
      other is DocPicture && other.id == id && other.turns == turns;

  @override
  int get hashCode => Object.hash(id, turns);
}

/// A document: a passport, a receipt (and its warranty), a card's
/// barcode, a ticket. Fields a kind doesn't use stay empty.
class DocItem {
  final String id;
  final DocKind kind;
  final String name;
  final String note;
  final List<DocPicture> pictures;

  /// The barcode (a Barcode or a Ticket): the id of its cropped picture.
  final String? barcode;

  /// A Document's expiry.
  final DateTime? expires;

  /// A Receipt's shop and price (free text, e.g. "349 €").
  final String shop;
  final String price;

  /// A Receipt's warranty: on, from and until.
  final bool warranty;
  final DateTime? warrantyFrom;
  final DateTime? warrantyTo;

  /// A Ticket's day.
  final DateTime? date;

  /// The reminder before its date (expiry, warranty end); a ticket's on
  /// its day when not [DocRemind.none].
  final DocRemind remind;

  final DateTime createdAt;

  const DocItem({
    required this.id,
    required this.kind,
    this.name = '',
    this.note = '',
    this.pictures = const [],
    this.barcode,
    this.expires,
    this.shop = '',
    this.price = '',
    this.warranty = false,
    this.warrantyFrom,
    this.warrantyTo,
    this.date,
    this.remind = DocRemind.none,
    required this.createdAt,
  });

  /// Nothing in it yet: a new one left so is discarded.
  bool get isEmpty =>
      name.trim().isEmpty &&
      note.trim().isEmpty &&
      pictures.isEmpty &&
      shop.trim().isEmpty &&
      price.trim().isEmpty;

  /// The date its reminder and colour go by: expiry, warranty end, the
  /// ticket's day; null if none.
  DateTime? get dueDate => switch (kind) {
        DocKind.document => expires,
        DocKind.receipt => warranty ? warrantyTo : null,
        DocKind.ticket => date,
        DocKind.barcode => null,
      };

  /// Every file it refers to.
  Set<String> get fileIds => {
        for (final p in pictures) p.id,
        if (barcode != null) barcode!,
      };

  DocItem copyWith({
    DocKind? kind,
    String? name,
    String? note,
    List<DocPicture>? pictures,
    String? Function()? barcode,
    DateTime? Function()? expires,
    String? shop,
    String? price,
    bool? warranty,
    DateTime? Function()? warrantyFrom,
    DateTime? Function()? warrantyTo,
    DateTime? Function()? date,
    DocRemind? remind,
  }) =>
      DocItem(
        id: id,
        kind: kind ?? this.kind,
        name: name ?? this.name,
        note: note ?? this.note,
        pictures: pictures ?? this.pictures,
        barcode: barcode == null ? this.barcode : barcode(),
        expires: expires == null ? this.expires : expires(),
        shop: shop ?? this.shop,
        price: price ?? this.price,
        warranty: warranty ?? this.warranty,
        warrantyFrom: warrantyFrom == null ? this.warrantyFrom : warrantyFrom(),
        warrantyTo: warrantyTo == null ? this.warrantyTo : warrantyTo(),
        date: date == null ? this.date : date(),
        remind: remind ?? this.remind,
        createdAt: createdAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.name,
        if (name.isNotEmpty) 'name': name,
        if (note.isNotEmpty) 'note': note,
        if (pictures.isNotEmpty)
          'pictures': [for (final p in pictures) p.toJson()],
        if (barcode != null) 'barcode': barcode,
        if (expires != null) 'expires': PlannerTask.dayToJson(expires!),
        if (shop.isNotEmpty) 'shop': shop,
        if (price.isNotEmpty) 'price': price,
        if (warranty) 'warranty': true,
        if (warrantyFrom != null)
          'warrantyFrom': PlannerTask.dayToJson(warrantyFrom!),
        if (warrantyTo != null)
          'warrantyTo': PlannerTask.dayToJson(warrantyTo!),
        if (date != null) 'date': PlannerTask.dayToJson(date!),
        if (remind != DocRemind.none) 'remind': remind.name,
        'createdAt': createdAt.toIso8601String(),
      };

  factory DocItem.fromJson(Map<String, dynamic> json) {
    DateTime? day(String key) =>
        json[key] == null ? null : PlannerTask.dayFromJson(json[key]);
    return DocItem(
      id: json['id'] as String,
      kind: DocKind.fromId(json['kind'] as String?),
      name: json['name'] as String? ?? '',
      note: json['note'] as String? ?? '',
      pictures: [
        for (final p in json['pictures'] as List<dynamic>? ?? const [])
          DocPicture.fromJson(p as Map<String, dynamic>),
      ],
      barcode: json['barcode'] as String?,
      expires: day('expires'),
      shop: json['shop'] as String? ?? '',
      price: json['price'] as String? ?? '',
      warranty: json['warranty'] as bool? ?? false,
      warrantyFrom: day('warrantyFrom'),
      warrantyTo: day('warrantyTo'),
      date: day('date'),
      remind: DocRemind.fromId(json['remind'] as String?),
      createdAt: DateTime.parse(json['createdAt'] as String),
    );
  }
}

/// Every document, in the user's order.
class DocumentBook {
  final List<DocItem> items;

  const DocumentBook(this.items);

  static const empty = DocumentBook([]);

  int get size => items.length;

  DocItem? byId(String id) => items.where((d) => d.id == id).firstOrNull;

  /// Every file the documents refer to.
  Set<String> get fileIds => {for (final d in items) ...d.fileIds};

  Map<String, dynamic> toJson() => {
        'documents': [for (final d in items) d.toJson()],
      };

  factory DocumentBook.fromJson(Map<String, dynamic> json) => DocumentBook([
        for (final d in json['documents'] as List<dynamic>? ?? const [])
          DocItem.fromJson(d as Map<String, dynamic>),
      ]);
}
