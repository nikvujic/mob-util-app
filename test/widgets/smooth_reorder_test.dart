import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/widgets/selection.dart';

import '../helpers.dart';

/// Dragging a row by its handle (`SmoothSliverReorderableList`): the rows
/// making room glide, even when the drag goes back and forth fast, and a
/// drop lands where the gap is shown, without a jump at the end; the list
/// scrolls up as the row enters the band at its top.
void main() {
  late ProviderContainer container;
  NotesNotifier notes() => container.read(notesProvider.notifier);

  Future<void> withNotes(WidgetTester tester, int n) async {
    container = await pumpApp(tester);
    for (var i = n - 1; i >= 0; i--) {
      notes().addNote(title: 'Note $i');
    }
    await tester.pump();
  }

  Finder handleOf(String title) => find
      .descendant(
        of: find.ancestor(
            of: find.text(title), matching: find.byType(SelectableCard)),
        matching: find.byIcon(Icons.drag_handle),
      )
      .first;

  testWidgets(
      'fast up and down, then let go: every row moves at most a smooth step '
      'a frame, the dropped one lands where the gap was, no jump at the end',
      (tester) async {
    await withNotes(tester, 5);
    final titles = [for (var i = 0; i < 5; i++) 'Note $i'];
    double y(String t) => tester.getTopLeft(find.text(t).first).dy;
    final rowHeight = y('Note 1') - y('Note 0');
    var last = {for (final t in titles) t: y(t)};
    var worst = 0.0;
    String? worstAt;
    void check(String when) {
      for (final t in titles) {
        final now = y(t);
        final step = (now - last[t]!).abs();
        if (step > worst) {
          worst = step;
          worstAt = '$t $when';
        }
        last[t] = now;
      }
    }

    final gesture =
        await tester.startGesture(tester.getCenter(handleOf('Note 1')));
    await tester.pump(const Duration(milliseconds: 16));
    // Fast: down two rows, up three, down two, in quick strokes.
    for (final (dy, frames) in [
      (rowHeight * 2.2, 4),
      (-rowHeight * 3.1, 5),
      (rowHeight * 2.0, 3),
    ]) {
      for (var i = 0; i < frames; i++) {
        await gesture.moveBy(Offset(0, dy / frames));
        await tester.pump(const Duration(milliseconds: 16));
        check('dragging');
      }
    }
    // Let go at once, mid-glide.
    await gesture.up();
    for (var i = 0; i < 60; i++) {
      await tester.pump(const Duration(milliseconds: 16));
      check('dropping');
    }
    await tester.pumpAndSettle();
    check('settled');
    // The drag itself moves the row with the finger (up to a third of a
    // row a frame here); nothing else may jump more than that.
    expect(worst, lessThanOrEqualTo(rowHeight * 0.75),
        reason: 'jumped ${worst.toStringAsFixed(1)} px: $worstAt');
    // Where it landed is its place in the list, in order on screen.
    final order = [...titles]..sort((a, b) => y(a).compareTo(y(b)));
    expect(container.read(notesProvider).map((n) => n.title).toList(), order);
  });

  testWidgets(
      'picked up below the top band, a small move up into it scrolls the '
      'list; picked up inside it, only the very edge does', (tester) async {
    await withNotes(tester, 40);
    final list = find.byType(Scrollable).first;
    // Scrolled down a way: rows above to come back.
    await tester.drag(list, const Offset(0, -900));
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(list).position;
    final before = position.pixels;
    expect(before, greaterThan(300));
    final listRect = tester.getRect(list);
    // A row in the middle of the list: lifted up only a little, into the
    // band (well short of the top edge).
    final mid = find.byType(SelectableCard).evaluate().map((e) {
      final box = e.renderObject! as RenderBox;
      return box.localToGlobal(Offset.zero).dy;
    }).where((dy) => dy > listRect.top + listRect.height * 0.5);
    expect(mid, isNotEmpty);
    final startY = mid.first + 20;
    final handle = find.byIcon(Icons.drag_handle).evaluate().firstWhere((e) {
      final box = e.renderObject! as RenderBox;
      final dy = box.localToGlobal(Offset.zero).dy;
      return (dy - mid.first).abs() < 40;
    });
    final at = tester.getCenter(find.byWidget(handle.widget).first);
    final gesture = await tester.startGesture(Offset(at.dx, startY));
    await tester.pump(const Duration(milliseconds: 16));
    final band = listRect.height * 0.28;
    final target = listRect.top + band - 20;
    for (var i = 0; i < 10; i++) {
      await gesture.moveBy(Offset(0, (target - startY) / 10));
      await tester.pump(const Duration(milliseconds: 16));
    }
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(position.pixels, lessThan(before - 50),
        reason: 'scrolling up, the row in the band, far from the edge');
    await gesture.up();
    await tester.pumpAndSettle();
  });

  testWidgets(
      'picked up inside the top band, moving it up a little doesn\'t '
      'scroll (only the very edge does)', (tester) async {
    await withNotes(tester, 40);
    final list = find.byType(Scrollable).first;
    await tester.drag(list, const Offset(0, -900));
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(list).position;
    final before = position.pixels;
    final listRect = tester.getRect(list);
    final band = listRect.height * 0.28;
    // A handle inside the band, below the edge.
    final inBand = find.byIcon(Icons.drag_handle).evaluate().map((e) {
      final box = e.renderObject! as RenderBox;
      return box.localToGlobal(box.size.center(Offset.zero));
    }).where((c) => c.dy > listRect.top + 60 && c.dy < listRect.top + band);
    expect(inBand, isNotEmpty);
    final start = inBand.first;
    final gesture = await tester.startGesture(start);
    await tester.pump(const Duration(milliseconds: 16));
    await gesture.moveBy(const Offset(0, -20));
    for (var i = 0; i < 30; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(position.pixels, before, reason: 'not scrolled');
    await gesture.up();
    await tester.pumpAndSettle();
  });
}
