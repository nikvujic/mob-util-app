import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/widgets/markdown_text.dart';

import '../helpers.dart';

/// The text menu (Cut, Copy...) stays on the screen for a selection
/// taller than the view, so its buttons can be tapped.
void main() {
  final contentField = find.byKey(const Key('noteContentField'));
  MarkdownEditingController content(WidgetTester tester) =>
      tester.widget<TextField>(contentField).controller!
          as MarkdownEditingController;

  for (final editing in [false, true]) {
    testWidgets(
        'a long paragraph between empty lines, selected and cut '
        '(${editing ? 'while editing' : 'held first'})', (tester) async {
      String? clipboard;
      tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
      addTearDown(() => tester.binding.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null));
      final container = await pumpApp(tester);
      final paragraph = List.filled(300, 'word').join(' ');
      container
          .read(notesProvider.notifier)
          .addNote(title: 'Long', content: '\n$paragraph\n');
      await tester.pump();
      await tester.tap(find.text('Long'));
      await tester.pumpAndSettle();
      if (editing) {
        await tester.tap(contentField);
        await tester.pumpAndSettle();
      }
      final scroll = find.byKey(const Key('noteContentScroll'));
      await tester
          .longPressAt(tester.getTopLeft(scroll) + const Offset(40, 40));
      await tester.pumpAndSettle();
      // Line 2 only, past the bottom of the view.
      content(tester).selection =
          TextSelection(baseOffset: 1, extentOffset: 1 + paragraph.length);
      await tester.pumpAndSettle();
      final screen =
          Offset.zero & tester.view.physicalSize / tester.view.devicePixelRatio;
      final cut = tester.getRect(find.text('Cut'));
      expect(screen.contains(cut.topLeft) && screen.contains(cut.bottomRight),
          isTrue);
      await tester.tap(find.text('Cut'));
      await tester.pumpAndSettle();
      expect(clipboard, paragraph);
      expect(content(tester).text, '\n\n');
    });
  }
}
