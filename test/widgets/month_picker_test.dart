import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/month_picker.dart';

/// The month picker (Round 85; Round 86: three across, spaced).
void main() {
  void open(WidgetTester tester, {double width = 1080, double scale = 1}) {
    tester.view.physicalSize = Size(width, 1800);
    tester.view.devicePixelRatio = 2.625;
    tester.platformDispatcher.textScaleFactorTestValue = scale;
    addTearDown(tester.view.reset);
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  }

  Future<Future<DateTime?>> show(WidgetTester tester) async {
    late Future<DateTime?> picked;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.dark,
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => picked = showMonthPicker(context,
                title: 'Card expires',
                initial: DateTime(2026, 10),
                firstYear: 2021,
                lastYear: 2041),
            child: const Text('go'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('go'));
    await tester.pumpAndSettle();
    return picked;
  }

  for (final (width, scale) in [(1080.0, 1.0), (945.0, 1.3)]) {
    testWidgets('three across, four rows, spaced apart ($width, $scale)',
        (tester) async {
      open(tester, width: width, scale: scale);
      await show(tester);
      Rect at(int month) => tester.getRect(find.byKey(Key('month-$month')));
      for (var month = 1; month <= 12; month++) {
        final r = at(month);
        expect(r.height, greaterThanOrEqualTo(44));
        if (month % 3 != 0) {
          expect(at(month + 1).left - r.right, greaterThanOrEqualTo(7.99),
              reason: '$month and the next, side by side');
          expect(at(month + 1).top, r.top, reason: 'one row');
        }
        if (month <= 9) {
          expect(at(month + 3).top - r.bottom, greaterThanOrEqualTo(7.99),
              reason: '$month and the one below');
        }
      }
      expect(tester.takeException(), isNull, reason: 'no overflow');
    });
  }

  testWidgets('a year on, then a month: its first day', (tester) async {
    open(tester);
    final picked = await show(tester);
    await tester.tap(find.byTooltip('Year after'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('month-3')));
    await tester.pumpAndSettle();
    expect(await picked, DateTime(2027, 3));
  });
}
