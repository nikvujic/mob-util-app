import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/pages/notes/note_history.dart';

/// Undo / redo steps in the note editor (N8).
void main() {
  late DateTime now;
  late NoteHistory history;

  NoteText text(String title, String content) => (
        title: TextEditingValue(text: title),
        content: TextEditingValue(text: content),
      );

  setUp(() {
    now = DateTime(2026, 10, 10, 12);
    history = NoteHistory(text('T', ''), clock: () => now);
  });

  /// Types [content] one character at a time, [gap] apart.
  void type(String before, String added,
      {Duration gap = const Duration(milliseconds: 100)}) {
    for (var i = 1; i <= added.length; i++) {
      now = now.add(gap);
      history.changed(text('T', before + added.substring(0, i)));
    }
  }

  String? undo() => history.undo()?.content.text;
  String? redo() => history.redo()?.content.text;

  test('starts with nothing to undo or redo', () {
    expect((history.canUndo, history.canRedo), (false, false));
    expect(history.undo(), isNull);
    expect(history.redo(), isNull);
  });

  test('a burst of typing is one step; a pause starts the next', () {
    type('', 'Hello');
    now = now.add(NoteHistory.pause);
    type('Hello', ' world');

    expect(undo(), 'Hello');
    expect(undo(), '');
    expect(history.canUndo, isFalse);
  });

  test('a paste is a step of its own, and so is typing right after it', () {
    type('', 'Hi ');
    now = now.add(const Duration(milliseconds: 100));
    history.changed(text('T', 'Hi pasted from somewhere'));
    type('Hi pasted from somewhere', '!');

    expect(undo(), 'Hi pasted from somewhere');
    expect(undo(), 'Hi ');
    expect(undo(), '');
  });

  test('deleting a lot at once is a step too', () {
    type('', 'abc');
    history.changed(text('T', 'abc and a long tail to cut'));
    history.changed(text('T', 'abc'));
    expect(undo(), 'abc and a long tail to cut');
  });

  test('redo goes forward again; a new edit drops what was undone', () {
    type('', 'one');
    now = now.add(NoteHistory.pause);
    type('one', ' two');

    expect(undo(), 'one');
    expect(redo(), 'one two');
    expect(history.canRedo, isFalse);

    expect(undo(), 'one');
    type('one', '!');
    expect(history.canRedo, isFalse);
    expect(undo(), 'one');
  });

  test('typing after an undo is a new step', () {
    type('', 'one');
    now = now.add(NoteHistory.pause);
    type('one', ' two');
    undo();
    type('one', ' three'); // within the pause of the undone typing

    expect(undo(), 'one');
    expect(undo(), '');
  });

  test('title and text share the history, as separate steps', () {
    type('', 'Body');
    now = now.add(const Duration(milliseconds: 100));
    history.changed(text('Title', 'Body'));

    expect(history.undo()!.title.text, 'T');
    expect(history.undo()!.content.text, '');
  });

  test('moving the cursor is not a step, but undo restores the cursor', () {
    type('', 'Hello');
    history.changed((
      title: const TextEditingValue(text: 'T'),
      content: const TextEditingValue(
        text: 'Hello',
        selection: TextSelection.collapsed(offset: 2),
      ),
    ));
    now = now.add(NoteHistory.pause);
    history.changed(text('T', 'Hello there'));

    final back = history.undo()!;
    expect(back.content.text, 'Hello');
    expect(back.content.selection, const TextSelection.collapsed(offset: 2));
    expect(undo(), '');
  });

  test('keeps the last ${NoteHistory.limit} steps', () {
    var content = '';
    for (var i = 0; i < NoteHistory.limit + 20; i++) {
      now = now.add(NoteHistory.pause);
      history.changed(text('T', content += 'x'));
    }
    var steps = 0;
    while (history.undo() != null) {
      steps++;
    }
    expect(steps, NoteHistory.limit);
  });
}
