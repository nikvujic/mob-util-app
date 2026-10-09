import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/widgets/pull_down_list.dart';

void main() {
  /// A 600 dp high list of [count] 60 dp rows.
  Future<void> pumpList(WidgetTester tester, int count) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: PullDownList(
              slivers: [
                SliverList.list(
                  children: [
                    for (var i = 0; i < count; i++)
                      SizedBox(height: 60, child: Text('Row $i')),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  double topOfFirstRow(WidgetTester tester) =>
      tester.getTopLeft(find.text('Row 0')).dy;

  const reach = 600 * PullDownList.reach;

  for (final count in [30, 1]) {
    group(count == 1 ? 'a short list' : 'a long list', () {
      testWidgets('opens at its normal top', (tester) async {
        await pumpList(tester, count);
        expect(topOfFirstRow(tester), 0);
      });

      testWidgets('can be pulled down and stays there', (tester) async {
        await pumpList(tester, count);

        await tester.drag(find.text('Row 0'), const Offset(0, 150));
        await tester.pumpAndSettle();

        expect(topOfFirstRow(tester), closeTo(150, 1));
      });

      testWidgets('is pulled down at most its reach', (tester) async {
        await pumpList(tester, count);

        await tester.drag(find.text('Row 0'), const Offset(0, 500));
        await tester.pumpAndSettle();

        expect(topOfFirstRow(tester), closeTo(reach, 1));
      });

      testWidgets('scrolling back up returns to the normal top',
          (tester) async {
        await pumpList(tester, count);
        await tester.drag(find.text('Row 0'), const Offset(0, 150));
        await tester.pumpAndSettle();

        await tester.drag(find.text('Row 0'), const Offset(0, -150));
        await tester.pumpAndSettle();

        expect(topOfFirstRow(tester), closeTo(0, 1));
      });
    });
  }
}
