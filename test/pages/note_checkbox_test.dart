import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/widgets/markdown_text.dart';

import '../helpers.dart';

/// Checkboxes in notes (N15): `- [ ] ` shows as a box, tapping the box
/// ticks it, Enter continues, and a button makes one.
void main() {
  late ProviderContainer container;
  final contentField = find.byKey(const Key('noteContentField'));

  MarkdownEditingController content(WidgetTester tester) =>
      tester.widget<TextField>(contentField).controller!
          as MarkdownEditingController;

  bool editing(WidgetTester tester) =>
      tester.widget<TextField>(contentField).focusNode!.hasFocus;

  Future<String> openNote(WidgetTester tester, String text) async {
    container = await pumpApp(tester);
    final id = container
        .read(notesProvider.notifier)
        .addNote(title: 'Shopping', content: text);
    await tester.pump();
    await tester.tap(find.text('Shopping'));
    await tester.pumpAndSettle();
    return id;
  }

  /// Where the character at [index] is drawn, on screen.
  Offset charAt(WidgetTester tester, int index) {
    final editable = _editableIn(tester);
    final box = editable
        .getBoxesForSelection(
          TextSelection(baseOffset: index, extentOffset: index + 1),
        )
        .first
        .toRect();
    return editable.localToGlobal(box.center);
  }

  testWidgets('shows a box for "[ ]", and ☑ once ticked', (tester) async {
    await openNote(tester, '- [ ] milk\n- [x] eggs');
    final shown = content(tester)
        .buildTextSpan(
          context: tester.element(contentField),
          withComposing: false,
        )
        .toPlainText();
    expect(shown, contains('☐'));
    expect(shown, contains('☑'));
    expect(shown, isNot(contains('[')));
  });

  testWidgets('tapping the box ticks it, without starting to edit',
      (tester) async {
    final id = await openNote(tester, 'Buy\n- [ ] milk');
    await tester.tapAt(charAt(tester, 6)); // the "["
    await tester.pump(const Duration(seconds: 1)); // autosave

    expect(content(tester).text, 'Buy\n- [x] milk');
    expect(editing(tester), isFalse);
    expect(
      container.read(notesProvider).firstWhere((n) => n.id == id).content,
      'Buy\n- [x] milk',
    );

    await tester.tapAt(charAt(tester, 6));
    await tester.pump();
    expect(content(tester).text, 'Buy\n- [ ] milk', reason: 'and back');
  });

  testWidgets('tapping the words still edits', (tester) async {
    await openNote(tester, '- [ ] milk and bread');
    await tester.tapAt(charAt(tester, 14));
    await tester.pump();
    expect(editing(tester), isTrue);
    expect(content(tester).text, '- [ ] milk and bread');
  });

  testWidgets('ticking is undone with ↶', (tester) async {
    await openNote(tester, '- [ ] milk');
    await tester.tapAt(charAt(tester, 2));
    await tester.pump(const Duration(seconds: 2));
    expect(content(tester).text, '- [x] milk');
    await tester.tap(find.byTooltip('Undo'));
    await tester.pump();
    expect(content(tester).text, '- [ ] milk');
  });

  testWidgets('Enter after one starts the next, empty', (tester) async {
    await openNote(tester, '');
    await tester.enterText(contentField, '- [x] milk');
    await tester.enterText(contentField, '- [x] milk\n');
    expect(content(tester).text, '- [x] milk\n- [ ] ');
  });

  group('the Checkbox button', () {
    testWidgets('while viewing, starts one at the end, ready to type',
        (tester) async {
      await openNote(tester, 'Buy');
      await tester.tap(find.byTooltip('Checkbox'));
      await tester.pump();
      expect(content(tester).text, 'Buy\n- [ ] ');
      expect(editing(tester), isTrue);
      expect(content(tester).selection.baseOffset, 'Buy\n- [ ] '.length);
    });

    testWidgets('while typing, makes the line one, and back', (tester) async {
      await openNote(tester, '');
      await tester.enterText(contentField, 'milk');
      await tester.tap(find.byTooltip('Checkbox'));
      await tester.pump();
      expect(content(tester).text, '- [ ] milk');
      expect(editing(tester), isTrue);
      await tester.tap(find.byTooltip('Checkbox'));
      await tester.pump();
      expect(content(tester).text, 'milk');
    });
  });
}

RenderEditable _editableIn(WidgetTester tester) {
  RenderEditable? found;
  void visit(RenderObject o) {
    if (o is RenderEditable) {
      found ??= o;
      return;
    }
    o.visitChildren(visit);
  }

  visit(tester.renderObject(find.byKey(const Key('noteContentField'))));
  return found!;
}
