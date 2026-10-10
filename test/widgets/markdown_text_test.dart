import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/markdown_text.dart';

/// Markdown styled as it's typed (N9).
void main() {
  late MarkdownEditingController controller;

  Future<void> pumpField(WidgetTester tester, String text) async {
    controller = MarkdownEditingController(text: text);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.of(AppPalette.green),
        home: Scaffold(
          body: TextField(
            controller: controller,
            maxLines: null,
            style: const TextStyle(fontSize: 16),
            inputFormatters: const [MarkdownListFormatter()],
          ),
        ),
      ),
    );
  }

  /// The styled pieces of the field's text.
  List<TextSpan> spans(WidgetTester tester) {
    final span = controller.buildTextSpan(
      context: tester.element(find.byType(TextField)),
      style: const TextStyle(fontSize: 16),
      withComposing: true,
    );
    return span.children!.cast<TextSpan>();
  }

  TextSpan spanOf(WidgetTester tester, String text) =>
      spans(tester).firstWhere((s) => s.text == text);

  testWidgets('shows exactly the text, styled', (tester) async {
    const text = '## Shopping\n- **milk**\n1. *eggs* ~~tea~~';
    await pumpField(tester, text);
    expect(spans(tester).map((s) => s.text).join(), text);

    final palette = AppPalette.green;
    expect(spanOf(tester, 'Shopping').style!.fontSize, greaterThan(16));
    expect(spanOf(tester, 'milk').style!.fontWeight, FontWeight.w700);
    expect(spanOf(tester, '- ').style!.color, palette.accent);
    expect(spanOf(tester, 'eggs').style!.fontStyle, FontStyle.italic);
    expect(spanOf(tester, 'tea').style!.decoration, TextDecoration.lineThrough);
  });

  testWidgets('the word the keyboard is composing stays underlined',
      (tester) async {
    await pumpField(tester, '');
    controller.value = const TextEditingValue(
      text: '- milk',
      selection: TextSelection.collapsed(offset: 6),
      composing: TextRange(start: 2, end: 6),
    );
    await tester.pump();
    final milk = spanOf(tester, 'milk');
    expect(milk.style!.decoration, TextDecoration.underline);
    expect(spans(tester).map((s) => s.text).join(), '- milk');
  });

  testWidgets('Enter continues a list; on an empty item it ends it',
      (tester) async {
    await pumpField(tester, '');
    await tester.enterText(find.byType(TextField), '- milk');
    await tester.enterText(find.byType(TextField), '- milk\n');
    expect(controller.text, '- milk\n- ');
    expect(controller.selection, const TextSelection.collapsed(offset: 9));

    await tester.enterText(find.byType(TextField), '- milk\n- \n');
    expect(controller.text, '- milk\n');
    expect(controller.selection, const TextSelection.collapsed(offset: 7));
  });

  testWidgets('numbered lists count on', (tester) async {
    await pumpField(tester, '');
    await tester.enterText(find.byType(TextField), '1. one');
    await tester.enterText(find.byType(TextField), '1. one\n');
    expect(controller.text, '1. one\n2. ');
  });

  testWidgets('pasting text with line breaks is left as it is', (tester) async {
    await pumpField(tester, '');
    await tester.enterText(find.byType(TextField), '- milk');
    await tester.enterText(find.byType(TextField), '- milk\n- eggs\n');
    expect(controller.text, '- milk\n- eggs\n');
  });

  group('symbols hide except on the line being edited', () {
    const text = '## Shopping\n- **milk**\nplain';

    bool hidden(TextSpan span) => span.style!.color == Colors.transparent;

    testWidgets('not typing: all hidden; list markers stay', (tester) async {
      await pumpField(tester, text);
      expect(spans(tester).map((s) => s.text).join(), text, reason: 'kept');
      expect(hidden(spanOf(tester, '## ')), isTrue);
      expect(spans(tester).where((s) => s.text == '**').every(hidden), isTrue);
      expect(hidden(spanOf(tester, '- ')), isFalse);
      expect(spanOf(tester, '- ').style!.color, AppPalette.green.accent);
    });

    testWidgets('typing: the cursor\'s line shows them, muted', (tester) async {
      await pumpField(tester, text);
      controller
        ..editing = true
        ..selection = const TextSelection.collapsed(offset: 15); // in milk
      await tester.pump();
      expect(hidden(spanOf(tester, '## ')), isTrue, reason: 'other line');
      final stars = spans(tester).where((s) => s.text == '**');
      expect(stars.any(hidden), isFalse);
      expect(stars.first.style!.color, AppPalette.green.textMuted);

      controller.selection = const TextSelection.collapsed(offset: 0);
      await tester.pump();
      expect(hidden(spanOf(tester, '## ')), isFalse);
      expect(spans(tester).where((s) => s.text == '**').every(hidden), isTrue);
    });

    testWidgets('a selection over several lines shows all of theirs',
        (tester) async {
      await pumpField(tester, text);
      controller
        ..editing = true
        ..selection = const TextSelection(baseOffset: 3, extentOffset: 16);
      await tester.pump();
      expect(spans(tester).where(hidden), isEmpty);
    });

    testWidgets('hidden symbols take no room on screen', (tester) async {
      await pumpField(tester, '## Title');
      final editable =
          tester.allRenderObjects.whereType<RenderEditable>().single;
      double x(int offset) =>
          editable.getLocalRectForCaret(TextPosition(offset: offset)).left;
      expect(x(3) - x(0), lessThan(1), reason: '"## " is invisible');
      expect(x(8) - x(3), greaterThan(20), reason: '"Title" is not');
    });
  });
}
