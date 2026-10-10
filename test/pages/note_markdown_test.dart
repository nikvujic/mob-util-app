import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/widgets/markdown_text.dart';

import '../helpers.dart';

/// Markdown basics in the note editor (N9).
void main() {
  late ProviderContainer container;
  late DateTime now;
  final contentField = find.byKey(const Key('noteContentField'));

  TextEditingController content(WidgetTester tester) =>
      tester.widget<TextField>(contentField).controller!;

  Future<String> openNote(WidgetTester tester) async {
    now = DateTime(2026, 10, 10, 12);
    container = await pumpApp(tester, clock: () => now);
    final id = container
        .read(notesProvider.notifier)
        .addNote(title: 'Shopping', content: '');
    await tester.pump();
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    return id;
  }

  testWidgets('the editor styles Markdown; the note stays plain text',
      (tester) async {
    final id = await openNote(tester);
    expect(content(tester), isA<MarkdownEditingController>());

    await tester.enterText(contentField, '- milk');
    await tester.enterText(contentField, '- milk\n');
    expect(content(tester).text, '- milk\n- ', reason: 'list continues');
    await tester.enterText(contentField, '- milk\n- **eggs**');
    await tester.pump(const Duration(seconds: 1)); // autosave

    final note = container.read(notesProvider).firstWhere((n) => n.id == id);
    expect(note.content, '- milk\n- **eggs**');
  });

  testWidgets('a list item started by Enter is undone with ↶', (tester) async {
    await openNote(tester);
    await tester.enterText(contentField, '- milk');
    now = now.add(const Duration(seconds: 2)); // a pause: a new step
    await tester.enterText(contentField, '- milk\n');
    await tester.pump();

    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(content(tester).text, '- milk');
  });

  testWidgets('symbols show only while typing in the text', (tester) async {
    await openNote(tester);
    final markdown = content(tester) as MarkdownEditingController;
    expect(markdown.editing, isFalse, reason: 'just opened: reading');

    await tester.tap(contentField);
    await tester.pump();
    expect(markdown.editing, isTrue);

    await tester.tap(find.byKey(const Key('noteTitleField')));
    await tester.pump();
    expect(markdown.editing, isFalse, reason: 'typing the title instead');
  });
}
