import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/notes_provider.dart';

void main() {
  late NotesNotifier notifier;

  setUp(() => notifier = NotesNotifier());

  List<String> titles() => notifier.state.map((n) => n.title).toList();

  test('new notes are added to the top', () {
    notifier.addNote(title: 'A');
    notifier.addNote(title: 'B');
    expect(titles(), ['B', 'A']);
  });

  test('reorder follows ReorderableListView index semantics', () {
    notifier
      ..addNote(title: 'C')
      ..addNote(title: 'B')
      ..addNote(title: 'A');

    notifier.reorder(0, 3); // drag A below C
    expect(titles(), ['B', 'C', 'A']);

    notifier.reorder(2, 0); // drag A back to top
    expect(titles(), ['A', 'B', 'C']);
  });

  test('updateNote changes fields and bumps modifiedAt only on change', () {
    final id = notifier.addNote(title: 'A');
    final before = notifier.state.single;

    notifier.updateNote(id, title: 'A', content: '');
    expect(identical(notifier.state.single, before), isTrue);

    notifier.updateNote(id, title: 'Renamed');
    expect(notifier.state.single.title, 'Renamed');
    expect(
      notifier.state.single.modifiedAt.isBefore(before.modifiedAt),
      isFalse,
    );
  });

  test('removeNotes deletes only the given ids', () {
    final a = notifier.addNote(title: 'A');
    notifier.addNote(title: 'B');
    final c = notifier.addNote(title: 'C');

    notifier.removeNotes({a, c});
    expect(titles(), ['B']);
  });
}
