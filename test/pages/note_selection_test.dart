import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/notes_provider.dart';

import '../helpers.dart';

/// Round 61: in a long note, the start handle dragged up past the text's
/// top scrolls it on gently, the selection following, to the first line
/// (it raced a screen at a time and jumped about, or stopped).
void main() {
  testWidgets(
      'the start handle held above the text: it creeps up to the first '
      'line, no jumps', (tester) async {
    final container = await pumpApp(tester);
    final text =
        [for (var i = 1; i <= 80; i++) 'line number $i here'].join('\n');
    container
        .read(notesProvider.notifier)
        .addNote(title: 'Note', content: text);
    await tester.pump();
    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
    final view = find.byKey(const Key('noteContentScroll'));
    final scroll = tester
        .state<ScrollableState>(
            find.descendant(of: view, matching: find.byType(Scrollable)).first)
        .position;
    scroll.jumpTo(scroll.maxScrollExtent);
    await tester.pumpAndSettle();
    final editable = tester.allRenderObjects.whereType<RenderEditable>().last;
    final last = text.length - 2;
    await tester.longPressAt(editable.localToGlobal(
        editable.getLocalRectForCaret(TextPosition(offset: last)).center));
    await tester.pumpAndSettle();
    final controller = tester
        .widget<TextField>(find.byKey(const Key('noteContentField')))
        .controller!;
    expect(controller.selection.isCollapsed, isFalse);
    final end = controller.selection.end;
    // The start handle hangs below the selection's start.
    final start = editable
        .getLocalRectForCaret(TextPosition(offset: controller.selection.start));
    final handle =
        editable.localToGlobal(start.bottomLeft) + const Offset(-8, 12);
    final gesture = await tester.startGesture(handle);
    await tester.pump(const Duration(milliseconds: 50));
    final top = tester.getTopLeft(view).dy;
    // Up past the top, wiggling a little there (each move a handle
    // update), then held still: only the edge scroll moves it then.
    var y = handle.dy;
    var was = scroll.pixels;
    var biggest = 0.0;
    void step() {
      final moved = (was - scroll.pixels).abs();
      if (moved > biggest) biggest = moved;
      expect(scroll.pixels, lessThanOrEqualTo(was + 0.5),
          reason: 'never back down');
      was = scroll.pixels;
    }

    while (y > top - 30) {
      y = (y - 20).clamp(top - 30, 9999.0);
      await gesture.moveTo(Offset(handle.dx, y));
      await tester.pump(const Duration(milliseconds: 16));
      step();
    }
    for (var i = 0; i < 20; i++) {
      await gesture.moveTo(Offset(handle.dx, top - (i.isEven ? 25 : 35)));
      await tester.pump(const Duration(milliseconds: 16));
      step();
    }
    for (var i = 0; i < 200; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      step();
    }
    expect(biggest, lessThan(40), reason: 'no screen-sized jumps');
    expect(scroll.pixels, 0, reason: 'at the top');
    expect(controller.selection.start, lessThan('line number 1 here'.length),
        reason: 'on the first line');
    expect(controller.selection.end, end, reason: 'its end where it was');
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
