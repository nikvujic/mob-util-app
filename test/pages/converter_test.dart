import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/hub_tool.dart';

import '../helpers.dart';

/// The unit converter (Round 118): two boxes per pair, either one fills
/// the other; nothing kept.
void main() {
  Future<void> openConverter(WidgetTester tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Hub');
    await tester.scrollUntilVisible(find.byTooltip('Converter'), 80,
        scrollable: find.byType(Scrollable).first);
    await tester.tap(find.byTooltip('Converter'));
    await tester.pumpAndSettle();
  }

  String text(String key) =>
      (find.byKey(Key(key)).evaluate().single.widget as TextField)
          .controller!
          .text;

  testWidgets(
      'typed on the left, the right shows it; on the right, the left; '
      'cleared, both empty', (tester) async {
    await openConverter(tester);
    // g ↔ oz is the first pair.
    await tester.enterText(find.byKey(const Key('unit-0-left')), '100');
    await tester.pump();
    expect(text('unit-0-right'), '3.527');
    await tester.enterText(find.byKey(const Key('unit-0-right')), '1');
    await tester.pump();
    expect(text('unit-0-left'), '28.35');
    await tester.enterText(find.byKey(const Key('unit-0-right')), '');
    await tester.pump();
    expect(text('unit-0-left'), '');
  });

  testWidgets('a temperature below zero; a comma for the decimals',
      (tester) async {
    await openConverter(tester);
    // °C ↔ °F comes after the five cooking pairs.
    await tester.enterText(find.byKey(const Key('unit-5-right')), '-4');
    await tester.pump();
    expect(text('unit-5-left'), '-20');
    await tester.enterText(find.byKey(const Key('unit-5-left')), '36,6');
    await tester.pump();
    expect(text('unit-5-right'), '97.88');
  });

  testWidgets('left and back: nothing kept', (tester) async {
    await openConverter(tester);
    await tester.enterText(find.byKey(const Key('unit-0-left')), '100');
    await tester.pump();
    await tester.pageBack();
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Converter'));
    await tester.pumpAndSettle();
    expect(text('unit-0-left'), '');
    expect(text('unit-0-right'), '');
  });

  test('nothing to lock or clear', () {
    expect(HubTool.converter.lockable, isFalse);
    expect(HubTool.converter.clearable, isFalse);
  });
}
