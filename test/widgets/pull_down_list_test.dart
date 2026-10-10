import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// Reach mode (U3): pulling a list that's already at its top shifts it
/// down for thumb reach; any scroll the other way snaps it back.
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

  /// Where row 0's top is (negative when scrolled past it).
  double topOfFirstRow(WidgetTester tester) =>
      tester.getTopLeft(find.text('Row 0', skipOffstage: false)).dy;

  /// The shift in reach mode: a share of the 600 dp list, in whole dp.
  final reach = (600 * PullDownList.reach).floorToDouble();

  final list = find.byType(PullDownList);

  Future<void> drag(WidgetTester tester, double dy) async {
    await tester.drag(list, Offset(0, dy));
    await tester.pumpAndSettle();
  }

  for (final count in [30, 1]) {
    group(count == 1 ? 'a short list' : 'a long list', () {
      testWidgets('opens at its normal top', (tester) async {
        await pumpList(tester, count);
        expect(topOfFirstRow(tester), 0);
      });

      testWidgets('pulling down at the top enters reach mode, which stays',
          (tester) async {
        await pumpList(tester, count);
        await drag(tester, 60);
        expect(topOfFirstRow(tester), reach, reason: 'shifted the full way');

        // Pulling further does nothing more.
        await drag(tester, 100);
        expect(topOfFirstRow(tester), reach);
      });

      testWidgets('any scroll the other way leaves it, back to the top',
          (tester) async {
        await pumpList(tester, count);
        await drag(tester, 60);

        await drag(tester, -20);
        expect(topOfFirstRow(tester), 0);
      });

      testWidgets('a small pull springs back', (tester) async {
        await pumpList(tester, count);
        await drag(tester, PullDownList.enterDistance - 10);
        expect(topOfFirstRow(tester), 0);
      });
    });
  }

  testWidgets(
      'scrolling to the top from further down stops at the top; '
      'a new pull then enters reach mode', (tester) async {
    await pumpList(tester, 30);
    await drag(tester, -300); // down the list
    expect(topOfFirstRow(tester), -300);

    // Back up, with plenty to spare: stops at the normal top.
    await drag(tester, 500);
    expect(topOfFirstRow(tester), 0);

    // A fling up the list from further down stops at the top too.
    await drag(tester, -300);
    await tester.fling(list, const Offset(0, 400), 3000);
    await tester.pumpAndSettle();
    expect(topOfFirstRow(tester), 0);

    // Now at the top: a new pull enters reach mode.
    await drag(tester, 60);
    expect(topOfFirstRow(tester), reach);
  });

  testWidgets('in reach mode, scrolling on into the list just scrolls',
      (tester) async {
    await pumpList(tester, 30);
    await drag(tester, 60);

    await drag(tester, -(reach + 200));
    expect(topOfFirstRow(tester), -200, reason: 'no snap back over it');

    // Out of reach mode: back up stops at the top.
    await drag(tester, 400);
    expect(topOfFirstRow(tester), 0);
  });

  testWidgets(
      'in reach mode, a small flick the other way snaps back as the finger '
      'lets go, not after coasting (or on the next touch)', (tester) async {
    await pumpList(tester, 30);
    await drag(tester, 60);

    await tester.fling(list, const Offset(0, -20), 400);
    await tester.pump(); // the snap (or coasting) starts
    await tester.pump(const Duration(milliseconds: 300));
    expect(topOfFirstRow(tester), closeTo(0, 1), reason: 'back at the top');
  });

  testWidgets('in reach mode, a strong flick up the list carries on into it',
      (tester) async {
    await pumpList(tester, 30);
    await drag(tester, 60);

    await tester.fling(list, const Offset(0, -60), 3000);
    await tester.pumpAndSettle();
    final position = tester.state<ScrollableState>(find.byType(Scrollable));
    expect(position.position.pixels, greaterThan(reach + 200),
        reason: 'scrolled on, past the first rows');
  });

  testWidgets('a reset sends a list in reach mode back to its top (G13)',
      (tester) async {
    final reset = ChangeNotifier();
    addTearDown(reset.dispose);
    await pumpList(tester, 30, reset: reset);
    await drag(tester, 60);

    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    reset.notifyListeners();
    await tester.pump();

    expect(topOfFirstRow(tester), 0);
  });

  group('reveal', () {
    Future<void> reveal(WidgetTester tester, String row) async {
      PullDownList.reveal(
        tester.element(find.text(row, skipOffstage: false)),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('scrolls a row below the screen up into view, just enough',
        (tester) async {
      await pumpList(tester, 30);
      await reveal(tester, 'Row 12'); // 720–780: just below the 600 dp list
      expect(tester.getBottomLeft(find.text('Row 12')).dy, 600);
    });

    testWidgets('scrolls back to a row above, but not into the reach space',
        (tester) async {
      await pumpList(tester, 30);
      await drag(tester, -300);
      await reveal(tester, 'Row 0');
      expect(topOfFirstRow(tester), 0);
    });

    testWidgets('leaves reach mode when it scrolls', (tester) async {
      await pumpList(tester, 30);
      await drag(tester, 60); // reach mode
      await reveal(tester, 'Row 10');
      await drag(tester, 1000); // back up: stops at the normal top
      expect(topOfFirstRow(tester), 0);
    });
  });
}
