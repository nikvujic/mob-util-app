import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/widgets/format_bar.dart';

/// The text's selection handles (Round 64): their touch area starts at
/// the handle and reaches down, not up into the line they mark (a tap on
/// the text there grabbed the left one). Round 74: it reaches out away
/// from the text, barely over it.
void main() {
  final controls = FormatBarSelectionControls(ValueNotifier(false));

  test('each handle as tall and wide as a touch area (no more)', () {
    final size = controls.getHandleSize(18);
    expect(size, const Size.square(kMinInteractiveDimension));
  });

  testWidgets('drawn at the top of it, where it marks the text',
      (tester) async {
    for (final type in [
      TextSelectionHandleType.left,
      TextSelectionHandleType.right,
    ]) {
      await tester.pumpWidget(MaterialApp(
        home: Align(
          alignment: Alignment.topLeft,
          child: Builder(
            builder: (context) => controls.buildHandle(context, type, 18),
          ),
        ),
      ));
      final box = tester.getRect(find.byType(SizedBox).first);
      expect(box.height, kMinInteractiveDimension, reason: type.name);
      final drawn = tester.getRect(find.byType(CustomPaint).last);
      expect(drawn.top, box.top, reason: type.name);
      expect(drawn.height, lessThan(kMinInteractiveDimension));
    }
  });

  testWidgets(
      'the cursor\'s one handle is drawn under the cursor, not off to the '
      'side', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final text = TextEditingController(text: 'Hello world, a line of text');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(20),
          child: TextField(
            controller: text,
            selectionControls: controls,
            maxLines: null,
          ),
        ),
      ),
    ));
    final at = tester.getTopLeft(find.byType(TextField)) + const Offset(40, 10);
    // Focused by the first tap; the second shows the handle.
    for (var i = 0; i < 2; i++) {
      await tester.tapAt(at);
      await tester.pump(const Duration(milliseconds: 500));
      await tester.pumpAndSettle();
    }
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    final caret = editable.localToGlobal(
        editable.getLocalRectForCaret(text.selection.base).center);
    final handle = tester.getRect(find.byWidgetPredicate(
        (w) => w is ValueListenableBuilder<Set<TextSelectionHandleType>>));
    expect(handle.center.dx, closeTo(caret.dx, 2));
    final drawn = tester.getRect(find
        .descendant(
            of: find.byWidgetPredicate((w) =>
                w is ValueListenableBuilder<Set<TextSelectionHandleType>>),
            matching: find.byType(CustomPaint))
        .last);
    expect(drawn.center.dx, closeTo(caret.dx, 2), reason: 'drawn under it');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets(
      'Round 74: a selection\'s handles: the touch area reaches out from '
      'the drawn handle, away from the text; on the text\'s side only a '
      'sliver', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    final text = TextEditingController(text: 'Hello world, a line of text');
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(40),
          child: TextField(
            controller: text,
            selectionControls: controls,
            maxLines: null,
          ),
        ),
      ),
    ));
    // Long-press a word: selected, both handles shown.
    await tester.longPressAt(
        tester.getTopLeft(find.byType(TextField)) + const Offset(60, 12));
    await tester.pumpAndSettle();
    expect(text.selection.isCollapsed, isFalse);
    final editable = tester
        .state<EditableTextState>(find.byType(EditableText))
        .renderEditable;
    double caretX(int offset) => editable
        .localToGlobal(
            editable.getLocalRectForCaret(TextPosition(offset: offset)).center)
        .dx;
    final start = caretX(text.selection.start);
    final end = caretX(text.selection.end);
    final areas = find.byWidgetPredicate((w) =>
        w is SizedBox &&
        w.width == kMinInteractiveDimension &&
        w.height == kMinInteractiveDimension);
    Rect area(Finder drawn) =>
        tester.getRect(find.ancestor(of: drawn, matching: areas).first);
    final painted = find.descendant(
        of: find.byWidgetPredicate(
            (w) => w is ValueListenableBuilder<Set<TextSelectionHandleType>>),
        matching: find.byType(CustomPaint));
    final rects = [
      for (final e in painted.evaluate())
        (tester.getRect(find.byWidget(e.widget)), area(find.byWidget(e.widget)))
    ]..sort((a, b) => a.$1.left.compareTo(b.$1.left));
    final (startDrawn, startArea) = rects.first;
    final (endDrawn, endArea) = rects.last;
    // The start's handle left of the text, its area reaching left.
    expect(startDrawn.right, closeTo(start, 2));
    expect(startArea.right - startDrawn.right,
        closeTo(FormatBarSelectionControls.inner, 0.5));
    expect(startArea.left, lessThan(startDrawn.left - 20));
    // The end's right of it, reaching right.
    expect(endDrawn.left, closeTo(end, 2));
    expect(endDrawn.left - endArea.left,
        closeTo(FormatBarSelectionControls.inner, 0.5));
    expect(endArea.right, greaterThan(endDrawn.right + 20));
    debugDefaultTargetPlatformOverride = null;
  });
}
