import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/other_tool.dart';

/// Where the pages go (O9): kept as ids, robust to pages coming and going.
void main() {
  test('every page once: repeats dropped, new pages at the end', () {
    final layout = PageLayout([OtherTool.counters, OtherTool.counters]);
    expect(layout.other, OtherTool.values);
    expect(PageLayout.initial.other, OtherTool.values);
  });

  test('unknown ids (a newer app\'s pages) are skipped, not fatal', () {
    final layout = PageLayout.fromJson({
      'other': ['from-the-future', 'counters'],
    });
    expect(layout.other, OtherTool.values);
    expect(PageLayout.fromJson({}).other, OtherTool.values);
  });

  test('saved as ids, and read back the same', () {
    final layout = PageLayout(OtherTool.values.reversed);
    expect(layout.toJson()['other'], [
      for (final t in OtherTool.values.reversed) t.name,
    ]);
    expect(PageLayout.fromJson(layout.toJson()).other, layout.other);
  });

  test('moving a page keeps the others in order', () {
    final layout = PageLayout.initial;
    final last = layout.other.last;
    final moved = layout.moved(last, 0);
    expect(moved.other.first, last);
    expect(moved.other.skip(1), layout.other.take(layout.other.length - 1));
    expect(layout.moved(last, 99).other.last, last, reason: 'clamped');
  });

  test('ids never change: they are what\'s stored', () {
    // Renaming one would lose the user's order (and later its lock).
    expect(OtherTool.values.map((t) => t.name), contains('counters'));
  });
}
