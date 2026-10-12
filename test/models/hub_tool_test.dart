import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/hub_tool.dart';

/// Where the pages go (O9): kept as ids, robust to pages coming and going.
void main() {
  test('every page once: repeats dropped, new pages at the end', () {
    final layout = PageLayout([HubTool.counters, HubTool.counters]);
    expect(layout.hub, HubTool.values);
    expect(PageLayout.initial.hub, HubTool.values);
  });

  test('unknown ids (a newer app\'s pages) are skipped, not fatal', () {
    final layout = PageLayout.fromJson({
      'hub': ['from-the-future', 'counters'],
    });
    expect(layout.hub, HubTool.values);
    expect(PageLayout.fromJson({}).hub, HubTool.values);
  });

  test('saved as ids, and read back the same', () {
    final layout = PageLayout(HubTool.values.reversed);
    expect(layout.toJson()['hub'], [
      for (final t in HubTool.values.reversed) t.name,
    ]);
    expect(PageLayout.fromJson(layout.toJson()).hub, layout.hub);
  });

  test('moving a page keeps the others in order', () {
    final layout = PageLayout.initial;
    final last = layout.hub.last;
    final moved = layout.moved(last, 0);
    expect(moved.hub.first, last);
    expect(moved.hub.skip(1), layout.hub.take(layout.hub.length - 1));
    expect(layout.moved(last, 99).hub.last, last, reason: 'clamped');
  });

  test('ids never change: they are what\'s stored', () {
    // Renaming one would lose the user's order (and later its lock).
    expect(HubTool.values.map((t) => t.name), contains('counters'));
  });

  test('version 1 (under "other", before the rename) still reads', () {
    final layout = PageLayout.fromJson({
      'other': ['medicine', 'counters'],
    });
    expect(layout.hub.take(2), [HubTool.medicine, HubTool.counters]);
  });
}
