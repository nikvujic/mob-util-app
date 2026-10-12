import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/notes_provider.dart';

import '../helpers.dart';

/// The note editor's text around the buttons at the bottom (Round 15):
/// nothing hides it, taps beside the buttons reach it, and its end can
/// scroll clear of them.
void main() {
  late ProviderContainer container;
  final contentField = find.byKey(const Key('noteContentField'));
  final text = List.generate(80, (i) => 'line $i').join('\n');

  Future<void> openNote(WidgetTester tester) async {
    container = await pumpApp(tester);
    container
        .read(notesProvider.notifier)
        .addNote(title: 'Note', content: text);
    await tester.pump();
    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
  }

  RenderEditable editable(WidgetTester tester) =>
      tester.allRenderObjects.whereType<RenderEditable>().last;

  /// Where paragraph `line [i]` is on screen.
  Rect lineRect(WidgetTester tester, int i) {
    final start = text.indexOf('line $i\n');
    final box = editable(tester);
    final rect = box.getLocalRectForCaret(TextPosition(offset: start));
    return rect.shift(box.localToGlobal(Offset.zero));
  }

  /// The top of the highest bottom button.
  double buttonsTop(WidgetTester tester) => [
        tester.getTopLeft(find.byTooltip('Undo')).dy,
        tester.getTopLeft(find.byTooltip('Edit title')).dy,
      ].reduce((a, b) => a < b ? a : b);

  TextSelection selection(WidgetTester tester) =>
      tester.widget<TextField>(contentField).controller!.selection;

  testWidgets('a line level with the buttons is shown and takes a tap',
      (tester) async {
    await openNote(tester);
    await tester.tap(contentField.first, warnIfMissed: false);
    await tester.pumpAndSettle();
    final top = buttonsTop(tester);
    // The first line whose row is level with the buttons.
    var i = 0;
    while (lineRect(tester, i).top < top + 8) {
      i++;
    }
    final row = lineRect(tester, i);
    final screen = tester.getSize(find.byType(MaterialApp));
    expect(row.bottom, lessThan(screen.height), reason: 'on screen');
    // Drawn, not cut off: inside the text's own box (padding in the field
    // used to hide the lines here).
    final box = editable(tester);
    final shown = box.localToGlobal(Offset.zero) & box.size;
    expect(shown.bottom, greaterThanOrEqualTo(row.bottom), reason: 'shown');

    // Beside the buttons (they're on one side), on that line.
    final x = tester.getTopLeft(find.byTooltip('Undo')).dx < screen.width / 2
        ? screen.width - 40
        : 40.0;
    await tester.tapAt(Offset(x, row.center.dy));
    await tester.pumpAndSettle();
    final start = text.indexOf('line $i\n');
    expect(selection(tester).baseOffset,
        inInclusiveRange(start, start + 'line $i'.length));
    // And it's scrolled up, clear of the buttons.
    expect(lineRect(tester, i).bottom, lessThanOrEqualTo(buttonsTop(tester)));
  });

  testWidgets('the end scrolls clear of the buttons', (tester) async {
    await openNote(tester);
    await tester.drag(
        find.byKey(const Key('noteContentScroll')), const Offset(0, -20000));
    await tester.pumpAndSettle();
    expect(lineRect(tester, 79).bottom, lessThanOrEqualTo(buttonsTop(tester)));
  });

  testWidgets('no magnifier when selecting', (tester) async {
    await openNote(tester);
    final field = tester.widget<TextField>(contentField);
    expect(field.magnifierConfiguration, TextMagnifierConfiguration.disabled);
  });
}
