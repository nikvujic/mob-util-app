import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/widgets/markdown_text.dart';

import '../helpers.dart';

/// The format bar (N17, Round 27): a row of buttons above the keyboard,
/// applying formats without leaving the text.
void main() {
  late ProviderContainer container;
  final contentField = find.byKey(const Key('noteContentField'));
  final bar = find.byKey(const Key('formatBar'));

  MarkdownEditingController content(WidgetTester tester) =>
      tester.widget<TextField>(contentField).controller!
          as MarkdownEditingController;

  bool editing(WidgetTester tester) =>
      tester.widget<TextField>(contentField).focusNode!.hasFocus;

  /// A note with [text], typing in it, the bar open.
  Future<void> openBar(WidgetTester tester, String text) async {
    container = await pumpApp(tester);
    container
        .read(notesProvider.notifier)
        .addNote(title: 'Recipes', content: text);
    await tester.pump();
    await tester.tap(find.text('Recipes'));
    await tester.pumpAndSettle();
    await tester.tap(contentField);
    await tester.pump();
    await tester.tap(find.byTooltip('Format'));
    await tester.pump();
  }

  testWidgets(
      'while it\'s open, no cursor handle to cover it; the Tt icon '
      '(Round 29)', (tester) async {
    container = await pumpApp(tester);
    container
        .read(notesProvider.notifier)
        .addNote(title: 'Recipes', content: 'Pancakes and more');
    await tester.pump();
    await tester.tap(find.text('Recipes'));
    await tester.pumpAndSettle();
    await tester.tap(contentField);
    await tester.pumpAndSettle();
    // Tapping again into the text shows the cursor's handle.
    await tester.tapAt(tester.getTopLeft(contentField) + const Offset(40, 12));
    await tester.pumpAndSettle();
    final hidden = find.byKey(const Key('cursorHandleHidden'));
    expect(hidden, findsNothing);
    expect(
        find.descendant(
          of: find.byTooltip('Format'),
          matching: find.byIcon(Icons.text_fields),
        ),
        findsOneWidget);

    await tester.tap(find.byTooltip('Format'));
    await tester.pump();
    expect(hidden, findsOneWidget);
    await tester.tap(find.byTooltip('Close formatting'));
    await tester.pump();
    expect(hidden, findsNothing);
  });

  testWidgets(
      'scrolled down, Select all: the handle at its start (out of view) '
      'isn\'t drawn over the app bar (Round 45)', (tester) async {
    container = await pumpApp(tester);
    final text = [for (var i = 1; i <= 80; i++) 'Line number $i'].join('\n');
    container
        .read(notesProvider.notifier)
        .addNote(title: 'Long', content: text);
    await tester.pump();
    await tester.tap(find.text('Long'));
    await tester.pumpAndSettle();
    final scroll = find.byKey(const Key('noteContentScroll'));
    await tester.drag(scroll, const Offset(0, -3000));
    await tester.pumpAndSettle();
    // Hold a word in view, then Select all.
    await tester.longPressAt(tester.getCenter(scroll));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(content(tester).selection.start, 0);
    expect(find.byKey(const Key('handleOffScreen-left')), findsOneWidget,
        reason: 'its line is far above, out of view');
    expect(find.byKey(const Key('handleOffScreen-right')), findsNothing,
        reason: 'the end is in view');
    // 1.29.1: and the menu with it.
    final copy = tester.getRect(find.text('Copy'));
    expect(copy.top, greaterThanOrEqualTo(tester.getRect(scroll).top));
  });

  testWidgets(
      'Select all on a long note: the menu is still there to Copy, in '
      'view (1.29.1: it was left far above, with the note\'s start)',
      (tester) async {
    container = await pumpApp(tester);
    addTearDown(tester.view.reset);
    final text = [for (var i = 1; i <= 80; i++) 'Line number $i'].join('\n');
    container
        .read(notesProvider.notifier)
        .addNote(title: 'Long', content: text);
    await tester.pump();
    await tester.tap(find.text('Long'));
    await tester.pumpAndSettle();
    // The keyboard up, a word near the top held.
    tester.view.viewInsets =
        FakeViewPadding(bottom: 250 * tester.view.devicePixelRatio);
    await tester.pumpAndSettle();
    final scroll = find.byKey(const Key('noteContentScroll'));
    await tester.longPressAt(tester.getTopLeft(scroll) + const Offset(60, 30));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Select all'));
    await tester.pumpAndSettle();
    expect(content(tester).selection,
        TextSelection(baseOffset: 0, extentOffset: text.length));
    final view = tester.getRect(scroll);
    final copy = tester.getRect(find.text('Copy'));
    expect(copy.top, greaterThanOrEqualTo(view.top));
    expect(copy.bottom, lessThanOrEqualTo(view.bottom));
  });

  void select(WidgetTester tester, int start, int end) =>
      content(tester).selection =
          TextSelection(baseOffset: start, extentOffset: end);

  Future<void> press(WidgetTester tester, String tooltip) async {
    await tester.ensureVisible(find.byTooltip(tooltip));
    await tester.tap(find.byTooltip(tooltip));
    await tester.pump();
  }

  testWidgets('opens above the buttons, full width; closes again',
      (tester) async {
    await openBar(tester, 'Pancakes');
    expect(bar, findsOneWidget);
    expect(tester.getBottomLeft(bar).dy,
        lessThan(tester.getTopLeft(find.byTooltip('Edit title')).dy));
    final screen = tester.getSize(find.byType(MaterialApp)).width;
    expect(tester.getSize(bar).width, greaterThan(screen * 0.8));
    for (final tooltip in [
      'Checkbox',
      'Bulleted list',
      'Numbered list',
      'Heading',
      'Bold',
      'Italic',
      'Code block',
      'Code',
      'Highlight',
      'Quote',
      'Divider',
    ]) {
      expect(find.byTooltip(tooltip, skipOffstage: false), findsOneWidget,
          reason: tooltip);
    }
    // Round 39: Strikethrough went, to make room for code blocks.
    expect(find.byTooltip('Strikethrough', skipOffstage: false), findsNothing);
    await tester.tap(find.byTooltip('Close formatting'));
    await tester.pump();
    expect(bar, findsNothing);
  });

  testWidgets('on a phone, Code block is in view without scrolling the bar',
      (tester) async {
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    await openBar(tester, 'Pancakes');
    final button = tester.getRect(find.byTooltip('Code block'));
    final row = tester.getRect(bar);
    expect(button.right, lessThanOrEqualTo(row.right));
    expect(button.left, greaterThanOrEqualTo(row.left));
  });

  testWidgets('formats the selection, still typing', (tester) async {
    await openBar(tester, 'Flour and eggs');
    select(tester, 0, 5);
    await press(tester, 'Bold');
    expect(content(tester).text, '**Flour** and eggs');
    expect(content(tester).selection,
        const TextSelection(baseOffset: 2, extentOffset: 7));
    expect(editing(tester), isTrue, reason: 'the keyboard stays');

    await press(tester, 'Bold'); // and back
    expect(content(tester).text, 'Flour and eggs');

    select(tester, 10, 14);
    await press(tester, 'Highlight');
    expect(content(tester).text, 'Flour and ==eggs==');
  });

  testWidgets('line buttons: heading, list, quote, code block, divider',
      (tester) async {
    await openBar(tester, 'Pancakes');
    select(tester, 3, 3);
    await press(tester, 'Heading');
    expect(content(tester).text, '# Pancakes');
    await press(tester, 'Heading');
    expect(content(tester).text, '## Pancakes');

    content(tester).text = 'milk\neggs';
    select(tester, 0, 9);
    await press(tester, 'Numbered list');
    expect(content(tester).text, '1. milk\n2. eggs');

    content(tester).text = 'wise words';
    select(tester, 2, 2);
    await press(tester, 'Quote');
    expect(content(tester).text, '> wise words');

    content(tester).text = 'x = 1';
    select(tester, 1, 1);
    await press(tester, 'Code block');
    expect(content(tester).text, '```\nx = 1\n```');

    content(tester).text = 'Intro';
    select(tester, 5, 5);
    await press(tester, 'Divider');
    expect(content(tester).text, 'Intro\n---\n');
    expect(editing(tester), isTrue);
  });

  testWidgets('drawn: a quote bar, a divider line, a code panel',
      (tester) async {
    await openBar(tester, '> wise\n---\n```\nx = 1\n```\nend');
    // Not editing those lines: they're drawn.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final painter =
        tester.renderObject<RenderCheckboxBoxes>(find.byType(CheckboxBoxes));
    expect(painter.paintedBars, hasLength(1));
    expect(painter.paintedRules, hasLength(1));
    expect(painter.paintedPanels, hasLength(1));
    final field = tester.getRect(contentField);
    expect(painter.paintedRules.single.width,
        moreOrLessEquals(field.width, epsilon: 1),
        reason: 'across');
  });

  testWidgets(
      'a code panel shows whole, with room round the code; the '
      'bundled font (Round 41)', (tester) async {
    await openBar(tester, '```\nx = 1\n```\nend');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final painter =
        tester.renderObject<RenderCheckboxBoxes>(find.byType(CheckboxBoxes));
    final box = painter.localToGlobal(Offset.zero);
    final panel = painter.paintedPanels.single.shift(box);
    final field = tester.getRect(contentField);
    expect(field.left - panel.left, moreOrLessEquals(codeInset));
    // Inside what the scroll shows (it clips): its corners aren't cut.
    final scroll = tester.getRect(find.byKey(const Key('noteContentScroll')));
    expect(panel.left, greaterThanOrEqualTo(scroll.left - 0.5));
    expect(panel.right, lessThanOrEqualTo(scroll.right + 0.5));

    final span = content(tester).buildTextSpan(
      context: tester.element(contentField),
      style: const TextStyle(fontSize: 16),
      withComposing: false,
    );
    final fonts = <String?>{};
    span.visitChildren((s) {
      if (s is TextSpan && (s.text ?? '').contains('x = 1')) {
        fonts.add(s.style?.fontFamily);
      }
      return true;
    });
    expect(fonts, {codeFont});
    // Bundled with the app (no fetching), its licence beside it.
    expect(File('assets/fonts/JetBrainsMono-Regular.ttf').existsSync(), isTrue);
    expect(File('assets/fonts/JetBrainsMono-OFL.txt').existsSync(), isTrue);
    expect(
        File('pubspec.yaml').readAsStringSync(), contains('family: $codeFont'));
  });

  testWidgets(
      'a ``` never closed draws no panel; code is a little smaller '
      '(Round 29)', (tester) async {
    await openBar(tester, 'text `code`\n```\nnot closed');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final painter =
        tester.renderObject<RenderCheckboxBoxes>(find.byType(CheckboxBoxes));
    expect(painter.paintedPanels, isEmpty);

    final span = content(tester).buildTextSpan(
      context: tester.element(contentField),
      style: const TextStyle(fontSize: 16),
      withComposing: false,
    );
    final code = span.children!
        .whereType<TextSpan>()
        .firstWhere((s) => s.text == 'code');
    expect(code.style!.fontSize, 16 * MarkdownEditingController.codeScale);
  });

  RenderEditable editableOf(WidgetTester tester) => tester
      .state<EditableTextState>(find.descendant(
          of: contentField, matching: find.byType(EditableText)))
      .renderEditable;

  /// Where [start] to [end] of the note's text is, in the painter's box.
  Rect textRect(WidgetTester tester, int start, int end) {
    final painter =
        tester.renderObject<RenderCheckboxBoxes>(find.byType(CheckboxBoxes));
    final editable = editableOf(tester);
    final rows = editable.getBoxesForSelection(
        TextSelection(baseOffset: start, extentOffset: end));
    var rect = rows.first.toRect();
    for (final row in rows.skip(1)) {
      rect = rect.expandToInclude(row.toRect());
    }
    return MatrixUtils.transformRect(editable.getTransformTo(painter), rect);
  }

  /// The styles the note's text is drawn with where it reads [part].
  List<TextStyle?> stylesOf(WidgetTester tester, String part) {
    final span = content(tester).buildTextSpan(
      context: tester.element(contentField),
      style: const TextStyle(fontSize: 16),
      withComposing: false,
    );
    final styles = <TextStyle?>[];
    span.visitChildren((s) {
      if (s is TextSpan && (s.text ?? '').contains(part)) styles.add(s.style);
      return true;
    });
    return styles;
  }

  testWidgets('a code panel has the same room above and below (Round 42)',
      (tester) async {
    await openBar(tester, 'before\n```\nx = 1\ny = 2\n```\nend');
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    final painter =
        tester.renderObject<RenderCheckboxBoxes>(find.byType(CheckboxBoxes));
    final panel = painter.paintedPanels.single;
    final text = content(tester).text;
    final code =
        textRect(tester, text.indexOf('x = 1'), text.indexOf('y = 2') + 5);
    final above = code.top - panel.top, below = panel.bottom - code.bottom;
    expect(above, greaterThan(2));
    expect(below, moreOrLessEquals(above, epsilon: 0.5));
  });

  testWidgets(
      'editing in a code block shows its ``` (faint), so an empty one '
      'can be found (Round 42)', (tester) async {
    await openBar(tester, 'before\n```\n```\nafter');
    // The cursor outside the block: the fences hidden.
    select(tester, 2, 2);
    await tester.pump();
    expect(stylesOf(tester, '```').map((s) => s?.fontSize),
        everyElement(lessThan(1)));
    // In it: both show, muted, and the panel takes them in.
    select(tester, 10, 10);
    await tester.pump();
    final shown = stylesOf(tester, '```');
    expect(shown, isNotEmpty);
    for (final style in shown) {
      expect(style!.fontSize, greaterThan(10));
      expect(style.color, isNot(Colors.transparent));
    }
    final painter =
        tester.renderObject<RenderCheckboxBoxes>(find.byType(CheckboxBoxes));
    expect(painter.paintedPanels, hasLength(1));
    // Not editing (focus gone): hidden again.
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pumpAndSettle();
    expect(stylesOf(tester, '```').map((s) => s?.fontSize),
        everyElement(lessThan(1)));
  });
}
