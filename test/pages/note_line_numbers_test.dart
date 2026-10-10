import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/widgets/line_numbers.dart';

import '../helpers.dart';

/// Line numbers in the note editor (N12).
void main() {
  late ProviderContainer container;
  final contentField = find.byKey(const Key('noteContentField'));

  Future<void> openNote(WidgetTester tester, String content) async {
    container = await pumpApp(tester);
    container
        .read(notesProvider.notifier)
        .addNote(title: 'Note', content: content);
    await tester.pump();
    await tester.tap(find.text('Note'));
    await tester.pumpAndSettle();
  }

  RenderLineNumbers gutter(WidgetTester tester) =>
      tester.renderObject<RenderLineNumbers>(find.byType(LineNumbers));
  List<int> numbers(WidgetTester tester) =>
      [for (final line in gutter(tester).painted) line.number];

  /// The middle of the screen row where [offset]'s paragraph starts.
  double rowMiddle(WidgetTester tester, int offset) {
    final editable = tester.allRenderObjects.whereType<RenderEditable>().last;
    final rect = editable.getLocalRectForCaret(TextPosition(offset: offset));
    return gutter(tester).globalToLocal(editable.localToGlobal(rect.center)).dy;
  }

  testWidgets('one number per paragraph, level with its first row',
      (tester) async {
    const text = 'one\ntwo\n\nfour';
    await openNote(tester, text);
    expect(numbers(tester), [1, 2, 3, 4]);
    final lines = gutter(tester).painted;
    for (final (i, start) in [0, 4, 8, 9].indexed) {
      expect(lines[i].y, closeTo(rowMiddle(tester, start), 0.5));
    }
  });

  testWidgets('a wrapped paragraph keeps one number', (tester) async {
    final long = List.filled(40, 'word').join(' '); // several rows
    await openNote(tester, '$long\nnext');
    final lines = gutter(tester).painted;
    expect(numbers(tester), [1, 2]);
    expect(lines[1].y - lines[0].y, greaterThan(60), reason: 'rows apart');
    expect(lines[1].y, closeTo(rowMiddle(tester, long.length + 1), 0.5));
  });

  testWidgets('they follow the text as it scrolls and changes', (tester) async {
    await openNote(tester, List.generate(60, (i) => 'line $i').join('\n'));
    expect(numbers(tester).first, 1);
    final visible = numbers(tester).length;
    expect(visible, lessThan(60), reason: 'only those on screen');

    await tester.drag(contentField, const Offset(0, -500));
    await tester.pumpAndSettle();
    expect(numbers(tester).first, greaterThan(1));
    expect(gutter(tester).painted.first.y,
        closeTo(rowMiddle(tester, _startOf(numbers(tester).first)), 0.5));

    await tester.enterText(contentField, 'a\nb');
    await tester.pumpAndSettle();
    expect(numbers(tester), [1, 2]);
  });

  testWidgets('Settings turns them off', (tester) async {
    await openNote(tester, 'one\ntwo');
    expect(find.byType(LineNumbers), findsOneWidget);
    container.read(preferencesProvider.notifier).setNoteLineNumbers(false);
    await tester.pump();
    expect(find.byType(LineNumbers), findsNothing);
  });
}

/// Where paragraph [number] starts in the 'line i' test text.
int _startOf(int number) {
  var offset = 0;
  for (var i = 0; i < number - 1; i++) {
    offset += 'line $i'.length + 1;
  }
  return offset;
}
