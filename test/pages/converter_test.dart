import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/units.dart';
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

  // Further down the page, out of view till scrolled to.
  Future<void> type(WidgetTester tester, String key, String value) async {
    await tester.scrollUntilVisible(find.byKey(Key(key)), 80,
        scrollable: find.byType(Scrollable).first);
    await tester.enterText(find.byKey(Key(key)), value);
    await tester.pump();
  }

  String text(String key) =>
      (find.byKey(Key(key)).evaluate().single.widget as TextField)
          .controller!
          .text;

  testWidgets(
      'typed on the left, the right shows it; on the right, the left; '
      'cleared, both empty', (tester) async {
    await openConverter(tester);
    // g ↔ oz: the first cooking pair, last group (Round 119).
    await type(tester, 'unit-7-left', '100');
    expect(text('unit-7-right'), '3.527');
    await type(tester, 'unit-7-right', '1');
    expect(text('unit-7-left'), '28.35');
    await type(tester, 'unit-7-right', '');
    expect(text('unit-7-left'), '');
  });

  testWidgets('a temperature below zero; a comma for the decimals',
      (tester) async {
    await openConverter(tester);
    // °C ↔ °F comes first (Round 119).
    await tester.enterText(find.byKey(const Key('unit-0-right')), '-4');
    await tester.pump();
    expect(text('unit-0-left'), '-20');
    await tester.enterText(find.byKey(const Key('unit-0-left')), '36,6');
    await tester.pump();
    expect(text('unit-0-right'), '97.88');
  });

  testWidgets('left and back: nothing kept', (tester) async {
    await openConverter(tester);
    await type(tester, 'unit-0-left', '100');
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

  testWidgets(
      'every box shows its unit and its name before anything is typed; '
      'temperature first, cooking last', (tester) async {
    await openConverter(tester);
    expect(find.text('Celsius (°C)'), findsOneWidget);
    expect(find.text('Fahrenheit (°F)'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('Pounds (lb)'), 80,
        scrollable: find.byType(Scrollable).first);
    expect(find.text('Kilograms (kg)'), findsOneWidget);
    expect(unitGroups.map((g) => g.title),
        ['Temperature', 'Length', 'Weight', 'Volume', 'Speed', 'Cooking']);
  });
}
