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

  test('done takes it off; undo puts it back where it was', () {
    todo
      ..add('A')
      ..add('B')
      ..add('C');
    final b = todo.state[1];
    final at = todo.complete(b.id);
    expect(texts(), ['A', 'C']);
    expect(at, 1);
    todo.restore(b, at!);
    expect(texts(), ['A', 'B', 'C']);
    // Twice is harmless; an unknown id does nothing.
    todo.restore(b, 0);
    expect(texts(), ['A', 'B', 'C']);
    expect(todo.complete('nope'), isNull);
  });

  test('undo after the list got shorter goes to the end', () {
    todo
      ..add('A')
      ..add('B')
      ..add('C');
    final c = todo.state[2];
    final at = todo.complete(c.id)!;
    todo.complete(idOf('A'));
    todo.restore(c, at);
    expect(texts(), ['B', 'C']);
  });

  test('edits text (blank leaves it) and reorders', () {
    todo
      ..add('A')
      ..add('B')
      ..add('C');
    todo.edit(idOf('B'), ' Bee ');
    todo.edit(idOf('Bee'), '  ');
    expect(texts(), ['A', 'Bee', 'C']);
    todo.reorder(0, 3); // A to the end
    expect(texts(), ['Bee', 'C', 'A']);
    todo.reorder(2, 0);
    expect(texts(), ['A', 'Bee', 'C']);
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
}
