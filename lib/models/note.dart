class Note {
  final String id;
  final String title;

  /// The text of the note; always empty while it's locked.
  final String content;
  final DateTime createdAt;
  final DateTime modifiedAt;

  /// For a locked note: its content, encrypted, as stored (opaque here —
  /// sealing and opening live in the providers layer). Null if not locked.
  final Map<String, dynamic>? lockedContent;

  const Note({
    required this.id,
    required this.title,
    required this.content,
    required this.createdAt,
    required this.modifiedAt,
    this.lockedContent,
  });

  bool get isLocked => lockedContent != null;

  /// A copy with other fields changed; keeps the lock state as it is.
  Note copyWith({
    String? id,
    String? title,
    String? content,
    DateTime? createdAt,
    DateTime? modifiedAt,
  }) {
    return Note(
      id: id ?? this.id,
      title: title ?? this.title,
      content: content ?? this.content,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      lockedContent: lockedContent,
    );
  }

  /// This note locked: [sealed] replaces its content.
  Note locked(Map<String, dynamic> sealed, {DateTime? modifiedAt}) => Note(
        id: id,
        title: title,
        content: '',
        createdAt: createdAt,
        modifiedAt: modifiedAt ?? this.modifiedAt,
        lockedContent: sealed,
      );

  /// This note unlocked, with its content in the clear again.
  Note unlocked(String content) => Note(
        id: id,
        title: title,
        content: content,
        createdAt: createdAt,
        modifiedAt: modifiedAt,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'content': content,
        'createdAt': createdAt.toIso8601String(),
        'modifiedAt': modifiedAt.toIso8601String(),
        if (lockedContent != null) 'lockedContent': lockedContent,
      };

  factory Note.fromJson(Map<String, dynamic> json) => Note(
        id: json['id'] as String,
        title: json['title'] as String,
        content: json['content'] as String,
        createdAt: DateTime.parse(json['createdAt'] as String),
        modifiedAt: DateTime.parse(json['modifiedAt'] as String),
        lockedContent: json['lockedContent'] as Map<String, dynamic>?,
      );
}
