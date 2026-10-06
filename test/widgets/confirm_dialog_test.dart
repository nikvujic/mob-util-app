import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/widgets/confirm_dialog.dart';

void main() {
  Future<Future<bool>> open(WidgetTester tester, {int count = 2}) async {
    late Future<bool> result;
    await tester.pumpWidget(MaterialApp(
      home: Builder(
        builder: (context) => TextButton(
          onPressed: () => result = showDeleteConfirmDialog(
            context,
            count: count,
            singular: 'note',
            plural: 'notes',
          ),
          child: const Text('open'),
        ),
      ),
    ));
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    return result;
  }

  testWidgets('pluralises the title', (tester) async {
    await open(tester, count: 1);
    expect(find.text('Delete note?'), findsOneWidget);
  });

  testWidgets('resolves true on confirm', (tester) async {
    final result = await open(tester);
    expect(find.text('Delete 2 notes?'), findsOneWidget);
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(await result, isTrue);
  });

  testWidgets('resolves false on cancel and on dismiss', (tester) async {
    var result = await open(tester);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(await result, isFalse);

    result = await open(tester);
    await tester.tapAt(const Offset(5, 5)); // barrier
    await tester.pumpAndSettle();
    expect(await result, isFalse);
  });
}
