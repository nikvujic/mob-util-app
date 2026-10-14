import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/models/todo_item.dart';
import 'package:the_app/providers/section_data_provider.dart';
import 'package:the_app/providers/todo_provider.dart';

/// The to-do note's list (Round 28).
void main() {
  late TodoNotifier todo;

  setUp(() => todo = TodoNotifier(AppStorage.inMemory()));

  List<String> texts() => todo.state.map((i) => i.text).toList();
  String idOf(String text) => todo.state.firstWhere((i) => i.text == text).id;

  test('adds trimmed text at the end and ignores blanks', () {
    todo
      ..add('Call mum')
      ..add('  Pay rent ')
      ..add('   ');
    expect(texts(), ['Call mum', 'Pay rent']);
    expect(todo.state.map((i) => i.id).toSet(), hasLength(2));
  });

  List<String> open() => [
        for (final i in todo.state)
          if (!i.done) i.text,
      ];
  List<String> done() => [
        for (final i in todo.state)
          if (i.done) i.text,
      ];

  test(
      'done goes to the top of Completed; back, to the end of To do '
      '(Round 30)', () {
    todo
      ..add('A')
      ..add('B')
      ..add('C');
    todo.toggle(idOf('B'));
    todo.toggle(idOf('A'));
    expect(open(), ['C']);
    expect(done(), ['A', 'B'], reason: 'the latest on top');
    todo.toggle(idOf('B'));
    expect(open(), ['C', 'B']);
    todo.add('D');
    expect(open(), ['C', 'B', 'D'], reason: 'added to To do');
    todo.toggle('nope'); // nothing
    expect(todo.state, hasLength(4));
  });

  test('Delete completed takes only the done ones', () {
    todo
      ..add('A')
      ..add('B')
      ..add('C');
    todo
      ..toggle(idOf('A'))
      ..toggle(idOf('C'));
    final gone = todo.deleteCompleted();
    expect(gone.map((i) => i.text), ['C', 'A']);
    expect(texts(), ['B']);
    expect(todo.deleteCompleted(), isEmpty);
  });

  test('edits text (blank leaves it); reorders within one list', () {
    todo
      ..add('A')
      ..add('B')
      ..add('C')
      ..add('X');
    todo.toggle(idOf('X'));
    todo.edit(idOf('B'), ' Bee ');
    todo.edit(idOf('Bee'), '  ');
    expect(open(), ['A', 'Bee', 'C']);
    todo.reorder(done: false, oldIndex: 0, newIndex: 3); // A to the end
    expect(open(), ['Bee', 'C', 'A']);
    todo.reorder(done: false, oldIndex: 2, newIndex: 0);
    expect(open(), ['A', 'Bee', 'C']);
    expect(done(), ['X'], reason: 'the other list as it was');
  });

  test('saved to todo.json and loaded back', () async {
    final dir = Directory.systemTemp.createTempSync('todo');
    addTearDown(() => dir.deleteSync(recursive: true));
    final storage = await AppStorage.open(directory: dir);
    TodoNotifier(storage)
      ..add('One')
      ..add('Two');
    await storage.flush();
    final again = await AppStorage.open(directory: dir);
    expect(again.initialTodo.map((i) => i.text), ['One', 'Two']);
  });

  test('part of Notes: counted and cleared with it', () {
    final container = ProviderContainer(overrides: [
      appStorageProvider.overrideWithValue(AppStorage.inMemory(
        initialTodo: const [TodoItem(id: 't1', text: 'Something')],
      )),
    ]);
    addTearDown(container.dispose);
    final data = container.read(sectionDataProvider);
    expect(data.count(AppSection.notes), 1);
    data.clear(AppSection.notes);
    expect(container.read(todoProvider), isEmpty);
  });

  group('waiting (Round 45)', () {
    List<String> waiting() => [
          for (final i in todo.state)
            if (!i.done && i.waiting) i.text,
        ];
    List<String> toDo() => [
          for (final i in todo.state)
            if (!i.done && !i.waiting) i.text,
        ];

    test('placed between To do and Waiting, in the order given', () {
      todo
        ..add('A')
        ..add('B')
        ..add('C')
        ..add('Done');
      todo.toggle(idOf('Done'));
      todo.place(toDo: [idOf('C'), idOf('A')], waiting: [idOf('B')]);
      expect(toDo(), ['C', 'A']);
      expect(waiting(), ['B']);
      expect(done(), ['Done'], reason: 'Completed as it was');
      // And back.
      todo.place(toDo: [idOf('B'), idOf('C'), idOf('A')], waiting: []);
      expect(toDo(), ['B', 'C', 'A']);
      expect(waiting(), isEmpty);
    });

    test('ones not given (or done) are kept, not lost or moved', () {
      todo
        ..add('A')
        ..add('B')
        ..add('Done');
      todo.toggle(idOf('Done'));
      todo.place(toDo: [idOf('Done')], waiting: [idOf('A')]);
      expect(texts(), containsAll(['A', 'B', 'Done']));
      expect(done(), ['Done']);
      expect(waiting(), ['A']);
      expect(toDo(), ['B']);
    });

    test('done, it is no longer waiting; back, it is to do', () {
      todo.add('A');
      todo.place(toDo: [], waiting: [idOf('A')]);
      todo.toggle(idOf('A'));
      expect(todo.state.single.waiting, isFalse);
      todo.toggle(idOf('A'));
      expect(toDo(), ['A']);
    });

    test('kept in todo.json (only when waiting)', () async {
      final dir = Directory.systemTemp.createTempSync('todo_waiting');
      addTearDown(() => dir.deleteSync(recursive: true));
      final storage = await AppStorage.open(directory: dir);
      final notifier = TodoNotifier(storage)
        ..add('One')
        ..add('Two');
      notifier.place(toDo: [
        notifier.state.first.id
      ], waiting: [
        notifier.state.last.id,
      ]);
      await storage.flush();
      final json = File('${dir.path}/todo.json').readAsStringSync();
      expect(json, contains('"version":3'));
      expect('waiting'.allMatches(json), hasLength(1));
      final again = await AppStorage.open(directory: dir);
      expect(again.initialTodo.map((i) => (i.text, i.waiting)),
          [('One', false), ('Two', true)]);
    });
  });
}
