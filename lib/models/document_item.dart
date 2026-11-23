import 'package:the_app/models/planner_task.dart';

/// What a document is (spec: types). Its [name] is stored; never renamed.
enum DocKind {
  document('Document'),
  receipt('Receipt'),
  barcode('Barcode'),

  /// A QR code (a card's, a pass's): framed square, read as QR only.
  qr('QR code'),
  ticket('Ticket');

  const DocKind(this.label);

  final String label;

  /// Whether creating one opens the camera at once.
  bool get startsWithCamera => this != document;

  /// Whether it has a barcode of its own (a crop of one of its pictures).
  bool get hasBarcode => this == barcode || this == qr || this == ticket;

  /// Its crop frame is square (a QR code).
  bool get squareCrop => this == qr;

  static DocKind fromId(String? id) =>
      values.where((k) => k.name == id).firstOrNull ?? document;
}

/// How long before a date its reminder comes (a ticket's: [onTheDay] or
/// none).
enum DocRemind {
  none('None', 0),
  onTheDay('On the day', 0),
  week('A week before', 7),
  month('A month before', 30),
  threeMonths('Three months before', 91),
  sixMonths('Six months before', 182);

  const DocRemind(this.label, this.days);

  final String label;
  final int days;

  /// A document's or a warranty's choices (a ticket's is on its day).
  static const before = [none, week, month, threeMonths, sixMonths];

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

/// What a document's barcode says, once read: its text and its kind of
/// code (as the reader names it: `ean13`, `code128`, `qr`, …).
class DocCode {
  final String text;
  final String format;

  const DocCode(this.text, this.format);

  @override
  bool operator ==(Object other) =>
      other is DocCode && other.text == text && other.format == format;

  @override
  int get hashCode => Object.hash(text, format);
}

/// Where a shown barcode was left: moved by [dx], [dy] (logical pixels
/// from the middle) and zoomed by [scale]. Shown so again next time.
class CodeView {
  final double dx;
  final double dy;
  final double scale;

  const CodeView({this.dx = 0, this.dy = 0, this.scale = 1});

  static const centred = CodeView();

  bool get isCentred => dx == 0 && dy == 0 && scale == 1;

  Map<String, dynamic> toJson() => {
        if (dx != 0) 'dx': dx,
        if (dy != 0) 'dy': dy,
        if (scale != 1) 'scale': scale,
      };

  factory CodeView.fromJson(Map<String, dynamic> json) => CodeView(
        dx: (json['dx'] as num?)?.toDouble() ?? 0,
        dy: (json['dy'] as num?)?.toDouble() ?? 0,
        scale: ((json['scale'] as num?)?.toDouble() ?? 1).clamp(0.2, 10),
      );

  @override
  bool operator ==(Object other) =>
      other is CodeView &&
      other.dx == dx &&
      other.dy == dy &&
      other.scale == scale;

  @override
  int get hashCode => Object.hash(dx, dy, scale);
}

/// A document: a passport, a receipt (and its warranty), a card's
/// barcode, a ticket. Fields a kind doesn't use stay empty.
class DocItem {
  final String id;
  final DocKind kind;
  final String name;
  final String note;
  final List<DocPicture> pictures;

  /// The barcode (a Barcode, a QR code or a Ticket): the id of its
  /// cropped picture.
  final String? barcode;

  /// What its barcode says, once read ([scanned]): drawn sharp from it.
  final DocCode? scanned;

  /// Shown as its photo (the crop) rather than drawn from [scanned].
  final bool showPhoto;

  /// Where its barcode was last left when shown.
  final CodeView codeView;

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
    this.scanned,
    this.showPhoto = false,
    this.codeView = CodeView.centred,
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
      price.trim().isEmpty &&
      expires == null &&
      date == null &&
      !warranty;

  /// The date its reminder and colour go by: expiry, warranty end, the
  /// ticket's day; null if none.
  DateTime? get dueDate => switch (kind) {
        DocKind.document => expires,
        DocKind.receipt => warranty ? warrantyTo : null,
        DocKind.ticket => date,
        DocKind.barcode || DocKind.qr => null,
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
    DocCode? Function()? scanned,
    bool? showPhoto,
    CodeView? codeView,
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
        scanned: scanned == null ? this.scanned : scanned(),
        showPhoto: showPhoto ?? this.showPhoto,
        codeView: codeView ?? this.codeView,
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
        if (scanned != null)
          'scanned': {'text': scanned!.text, 'format': scanned!.format},
        if (showPhoto) 'showPhoto': true,
        if (!codeView.isCentred) 'codeView': codeView.toJson(),
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
      scanned: switch (json['scanned']) {
        {'text': final String text, 'format': final String format} =>
          DocCode(text, format),
        _ => null,
      },
      showPhoto: json['showPhoto'] as bool? ?? false,
      codeView: json['codeView'] is Map<String, dynamic>
          ? CodeView.fromJson(json['codeView'] as Map<String, dynamic>)
          : CodeView.centred,
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
