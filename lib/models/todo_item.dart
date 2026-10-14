/// One thing on the to-do note (Round 28). Done ones go down to the
/// *Completed* list (Round 30) until deleted; ones to do may be waiting
/// (on someone or something, Round 45), in a *Waiting* list of their own
/// when it's on.
class TodoItem {
  final String id;
  final String text;
  final bool done;
  final bool waiting;

  const TodoItem({
    required this.id,
    required this.text,
    this.done = false,
    this.waiting = false,
  });

  TodoItem copyWith({String? text, bool? done, bool? waiting}) => TodoItem(
        id: id,
        text: text ?? this.text,
        done: done ?? this.done,
        waiting: waiting ?? this.waiting,
      );

  /// `done` and `waiting` only when they are (todo.json 2 and 3).
  Map<String, dynamic> toJson() => {
        'id': id,
        'text': text,
        if (done) 'done': true,
        if (waiting) 'waiting': true,
      };

  factory TodoItem.fromJson(Map<String, dynamic> json) => TodoItem(
        id: json['id'] as String,
        text: json['text'] as String,
        done: json['done'] as bool? ?? false,
        waiting: json['waiting'] as bool? ?? false,
      );
}
