/// One thing on the to-do note (Round 28): just its text. Done ones are
/// removed, not kept.
class TodoItem {
  final String id;
  final String text;

  const TodoItem({required this.id, required this.text});

  TodoItem copyWith({String? text}) =>
      TodoItem(id: id, text: text ?? this.text);

  Map<String, dynamic> toJson() => {'id': id, 'text': text};

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
        id: json['id'] as String,
        text: json['text'] as String,
      );
}
