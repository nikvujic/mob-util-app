import 'package:flutter/material.dart';
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
      'Strikethrough',
      'Highlight',
      'Quote',
      'Code',
      'Code block',
      'Divider',
    ]) {
      expect(find.byTooltip(tooltip, skipOffstage: false), findsOneWidget,
          reason: tooltip);
    }
    await tester.tap(find.byTooltip('Close formatting'));
    await tester.pump();
    expect(bar, findsNothing);
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
}
