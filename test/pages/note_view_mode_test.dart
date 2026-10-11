import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/notes_provider.dart';

import '../helpers.dart';

/// Notes open for viewing; editing starts with a tap (N13).
void main() {
  late ProviderContainer container;
  final contentField = find.byKey(const Key('noteContentField'));
  final titleField = find.byKey(const Key('noteTitleField'));

  bool focused(WidgetTester tester, Finder field) => tester
      .widget<EditableText>(
        find.descendant(of: field, matching: find.byType(EditableText)),
      )
      .focusNode
      .hasFocus;
  bool editing(WidgetTester tester) =>
      focused(tester, contentField) || focused(tester, titleField);

  Future<void> openNote(WidgetTester tester) async {
    container = await pumpApp(tester);
    container
        .read(notesProvider.notifier)
        .addNote(title: 'Shopping', content: '- milk\n- eggs');
    await tester.pump();
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
  }

  testWidgets('a note opens for viewing; a tap edits', (tester) async {
    await openNote(tester);
    expect(editing(tester), isFalse);

    await tester.tap(contentField);
    await tester.pump();
    expect(focused(tester, contentField), isTrue);
  });

  testWidgets('back while editing goes to viewing, then leaves',
      (tester) async {
    await openNote(tester);
    await tester.tap(contentField);
    await tester.pump();

    await pressBack(tester);
    expect(editing(tester), isFalse);
    expect(contentField, findsOneWidget, reason: 'still on the note');

    await pressBack(tester);
    expect(contentField, findsNothing, reason: 'left (nothing changed)');
    expect(appBarTitle('Notes'), findsOneWidget);
  });

  testWidgets('also from the title', (tester) async {
    await openNote(tester);
    await tester.tap(titleField);
    await tester.pump();
    await pressBack(tester);
    expect(editing(tester), isFalse);
    expect(titleField, findsOneWidget);
  });

  testWidgets('closing the keyboard goes back to viewing', (tester) async {
    await openNote(tester);
    await tester.tap(contentField);
    await tester.pump();
    tester.view.viewInsets = const FakeViewPadding(bottom: 300);
    addTearDown(tester.view.resetViewInsets);
    await tester.pumpAndSettle();
    expect(editing(tester), isTrue);

    tester.view.viewInsets = FakeViewPadding.zero; // keyboard closed
    await tester.pumpAndSettle();
    expect(editing(tester), isFalse);
    expect(contentField, findsOneWidget, reason: 'still on the note');
  });

  testWidgets('a new note opens ready to type', (tester) async {
    container = await pumpApp(tester);
    await tester.tap(find.byTooltip('New note'));
    await tester.pumpAndSettle();
    expect(focused(tester, contentField), isTrue);
  });
}
