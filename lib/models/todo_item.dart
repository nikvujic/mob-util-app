/// One thing on the to-do note (Round 28). Done ones go down to the
/// *Completed* list (Round 30) until deleted.
class TodoItem {
  final String id;
  final String text;
  final bool done;

  const TodoItem({required this.id, required this.text, this.done = false});

  TodoItem copyWith({String? text, bool? done}) =>
      TodoItem(id: id, text: text ?? this.text, done: done ?? this.done);

  /// `done` only when it is (todo.json 2).
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        if (done) 'done': true,
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
        id: json['id'] as String,
        text: json['text'] as String,
        done: json['done'] as bool? ?? false,
      );
}
