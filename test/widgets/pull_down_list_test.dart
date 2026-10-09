import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/widgets/pull_down_list.dart';

void main() {
  /// A 600 dp high list of [count] 60 dp rows (under [reset], if given).
  Future<void> pumpList(
    WidgetTester tester,
    int count, {
    Listenable? reset,
  }) async {
    final list = PullDownList(
      slivers: [
        SliverList.list(
          children: [
            for (var i = 0; i < count; i++)
              SizedBox(height: 60, child: Text('Row $i')),
          ],
        ),
      ],
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SizedBox(
            height: 600,
            child: reset == null
                ? list
                : PullDownReset(signal: reset, child: list),
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

  group('snapping back to the top (U4)', () {
    // Pulled down at most 240 (40% of 600); snaps within 35% of that (84).
    testWidgets('scrolling up to just short of the top settles there',
        (tester) async {
      await pumpList(tester, 30);
      await tester.drag(find.text('Row 0'), const Offset(0, 150));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Row 0'), const Offset(0, -100)); // 50 left
      await tester.pumpAndSettle();

      expect(topOfFirstRow(tester), 0);
    });

    testWidgets('scrolling up a little from far down stays there',
        (tester) async {
      await pumpList(tester, 30);
      await tester.drag(find.text('Row 0'), const Offset(0, 200));
      await tester.pumpAndSettle();

      await tester.drag(find.text('Row 0'), const Offset(0, -50)); // 150 left
      await tester.pumpAndSettle();

      expect(topOfFirstRow(tester), closeTo(150, 1));
    });

    testWidgets('pulling down a little does not snap back', (tester) async {
      await pumpList(tester, 30);
      await tester.drag(find.text('Row 0'), const Offset(0, 30));
      await tester.pumpAndSettle();

      expect(topOfFirstRow(tester), closeTo(30, 1));
    });
  });

  testWidgets('a reset sends a pulled-down list back to its top (G13)',
      (tester) async {
    final reset = ChangeNotifier();
    addTearDown(reset.dispose);
    await pumpList(tester, 30, reset: reset);
    await tester.drag(find.text('Row 0'), const Offset(0, 200));
    await tester.pumpAndSettle();

    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    reset.notifyListeners();
    await tester.pump();

    expect(topOfFirstRow(tester), 0);
  });
}
