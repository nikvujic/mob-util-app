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

  group('showSaveChangesDialog', () {
    Future<Future<bool>> openSave(WidgetTester tester) async {
      late Future<bool> result;
      await tester.pumpWidget(MaterialApp(
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => result = showSaveChangesDialog(context),
            child: const Text('open'),
          ),
        ),
      ));
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('Yes saves, No discards', (tester) async {
      var result = await openSave(tester);
      await tester.tap(find.text('Yes'));
      await tester.pumpAndSettle();
      expect(await result, isTrue);

      result = await openSave(tester);
      await tester.tap(find.text('No'));
      await tester.pumpAndSettle();
      expect(await result, isFalse);
    });

    testWidgets('dismissing counts as save', (tester) async {
      final result = await openSave(tester);
      await tester.tapAt(const Offset(5, 5));
      await tester.pumpAndSettle();
      expect(await result, isTrue);
    });

    testWidgets('No is on the left, Yes on the right', (tester) async {
      await openSave(tester);
      expect(
        tester.getCenter(find.text('No')).dx,
        lessThan(tester.getCenter(find.text('Yes')).dx),
      );
    });
  });
}
