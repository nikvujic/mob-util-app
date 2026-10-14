import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/pip_life_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/widgets/pip_room.dart';
import 'package:the_app/widgets/pixel_text.dart';

import '../helpers.dart';

/// Pip Home (Round 35): his field on top, a card below swiped between
/// his status and his settings.
void main() {
  late ProviderContainer container;

  Future<void> open(WidgetTester tester, {int hour = 12}) async {
    // A phone's size (Nikola's): half of it is his field.
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 2.625;
    addTearDown(tester.view.reset);
    container =
        await pumpApp(tester, clock: () => DateTime(2026, 10, 13, hour));
    await openTab(tester, 'Hub');
    await tester.tap(find.byTooltip('Pip'));
    await tester.pumpAndSettle();
  }

  /// The words drawn in pixel letters, as screen readers hear them.
  Iterable<String> words() => find
      .byType(PixelText)
      .evaluate()
      .map((e) => (e.widget as PixelText).label);

  PipRoom room(WidgetTester tester) => tester.widget(find.byType(PipRoom));

  Future<void> toSettings(WidgetTester tester) async {
    await tester.fling(
        find.byKey(const Key('pipCard')), const Offset(-400, 0), 1000);
    await tester.pumpAndSettle();
  }

  Future<void> key(WidgetTester tester, String said) async {
    await tester.tap(find.bySemanticsLabel(said).last);
    await tester.pump();
  }

  testWidgets('his field, tall, in the sky of the hour; his status below',
      (tester) async {
    await open(tester, hour: 23);
    final scene = room(tester).scene!;
    expect(scene.place, PipPlace.home);
    expect(scene.part, DayPart.night);
    // Half the page, below the app bar (Round 36).
    final page = tester.getSize(find.byType(Scaffold).last).height;
    expect(tester.getSize(find.byType(PipRoom)).height,
        moreOrLessEquals((page - kToolbarHeight) / 2, epsilon: 12));
    // Pip as big as in the menu (Round 38), in a bigger field.
    expect(room(tester).pixel, PipRoom.smallPixel);
    // Born 1 October (the helper's), today the 13th: his 13th day.
    expect(words(), containsAll(['Pip', 'AGE 13 DAYS', 'BORN 1.10.2026']));
    expect(tester.getTopLeft(find.byKey(const Key('pipStatus'))).dy,
        greaterThan(tester.getBottomLeft(find.byType(PipRoom)).dy));
  });

  testWidgets('swiped: the settings', (tester) async {
    await open(tester);
    await toSettings(tester);
    expect(find.byKey(const Key('pipRename')), findsOneWidget);
    expect(find.byKey(const Key('pipAnimations')), findsOneWidget);
    expect(find.byKey(const Key('pipBackground')), findsOneWidget);
  });

  testWidgets('the background: picked from a list (Round 36)', (tester) async {
    await open(tester);
    expect(room(tester).scene!.background, PipBackground.field);
    await toSettings(tester);
    expect(words(), contains('FIELD >'), reason: 'the one in use');
    await tester.tap(find.byKey(const Key('pipBackground')));
    await tester.pumpAndSettle();
    for (final b in PipBackground.values) {
      expect(find.byKey(Key('pipBackground-${b.name}')), findsOneWidget);
    }
    expect(words(), contains('IN USE'));
    await tester.tap(find.byKey(const Key('pipBackground-field')));
    await tester.pump();
    expect(container.read(preferencesProvider).pipBackground, 'field');
    expect(room(tester).scene!.background, PipBackground.field);
    await tester.tap(find.byKey(const Key('pipBack')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pipRename')), findsOneWidget);
  });

  test('the background picked is kept; 1.5.0\'s on/off reads as Field', () {
    expect(const Preferences().pipBackground, 'field');
    expect(Preferences.fromJson(const {}).pipBackground, 'field');
    const picked = Preferences(pipBackground: 'meadow');
    expect(Preferences.fromJson(picked.toJson()).pipBackground, 'meadow');
    expect(Preferences.fromJson(const {'pipBackground': false}).pipBackground,
        'field');
  });

  group('rename, on the card\'s own keyboard', () {
    Future<void> openRename(WidgetTester tester) async {
      await open(tester);
      await toSettings(tester);
      await tester.tap(find.byKey(const Key('pipRename')));
      await tester.pumpAndSettle();
    }

    PixelText newName(WidgetTester tester) =>
        tester.widget(find.byKey(const Key('pipNewName')));

    testWidgets('typed, up to 6, saved with OK', (tester) async {
      final semantics = tester.ensureSemantics();
      await openRename(tester);
      expect(find.byType(EditableText), findsNothing, reason: 'no phone keys');
      expect(newName(tester).label, 'New name PIP');
      for (var i = 0; i < 3; i++) {
        await key(tester, 'Delete');
      }
      expect(newName(tester).label, 'No name yet');
      for (final c in 'BIPBOOP'.split('')) {
        await key(tester, c);
      }
      expect(newName(tester).label, 'New name BIPBOO', reason: 'only 6');
      await key(tester, 'Delete');
      await key(tester, 'Numbers');
      await key(tester, '2');
      await key(tester, 'Save the name');
      await tester.pumpAndSettle();
      expect(container.read(pipLifeProvider).name, 'BIPBO2');
      expect(find.byKey(const Key('pipRename')), findsOneWidget,
          reason: 'back on the settings');
      semantics.dispose();
    });

    testWidgets('no name, no OK; back keeps his', (tester) async {
      final semantics = tester.ensureSemantics();
      await openRename(tester);
      for (var i = 0; i < 3; i++) {
        await key(tester, 'Delete');
      }
      await key(tester, 'Save the name');
      expect(find.byKey(const Key('pipNewName')), findsOneWidget,
          reason: 'still renaming');
      await key(tester, 'X');
      await tester.tap(find.byKey(const Key('pipBack')));
      await tester.pumpAndSettle();
      expect(container.read(pipLifeProvider).name, 'Pip');
      semantics.dispose();
    });

    testWidgets('a narrow phone (360 wide): the keys fit', (tester) async {
      await openRename(tester);
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 3;
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('pipKeyMode')));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull, reason: 'no overflow');
      expect(tester.getSize(find.byKey(const Key('pipKeyDelete'))).width,
          greaterThan(40));
    });

    testWidgets('while renaming, the card stays put', (tester) async {
      await openRename(tester);
      await tester.fling(
          find.byKey(const Key('pipCard')), const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('pipNewName')), findsOneWidget);
    });
  });

  testWidgets('animations play in his field; busy, it says so', (tester) async {
    await open(tester);
    await toSettings(tester);
    await tester.tap(find.byKey(const Key('pipAnimations')));
    await tester.pumpAndSettle();
    final brain = room(tester).brain;
    expect(brain.activity, PipActivity.standing);
    await tester.tap(find.byKey(const Key('pipPlay-walk')));
    await tester.pump();
    expect(brain.activity, PipActivity.walking);
    await tester.tap(find.byKey(const Key('pipPlay-hatch')));
    await tester.pump();
    expect(brain.activity, PipActivity.hatching);
    await tester.tap(find.byKey(const Key('pipPlay-turn')));
    await tester.pump();
    expect(brain.activity, PipActivity.hatching, reason: 'not now');
    expect(words(), contains("HE'S BUSY, A MOMENT"));
    await tester.pump(const Duration(seconds: 2));
    expect(words(), isNot(contains("HE'S BUSY, A MOMENT")));
    await tester.tap(find.byKey(const Key('pipBack')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('pipAnimations')), findsOneWidget);
  });

  testWidgets('Charging (Round 44) plays in his field: the station rises',
      (tester) async {
    await open(tester);
    await toSettings(tester);
    await tester.tap(find.byKey(const Key('pipAnimations')));
    await tester.pumpAndSettle();
    final brain = room(tester).brain;
    // The last in the list: scrolled all the way down to it.
    await tester.drag(
      find.descendant(
        of: find.byKey(const Key('pipAnimationList')),
        matching: find.byType(Scrollable),
      ),
      const Offset(0, -600),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('pipPlay-charge')));
    await tester.pump();
    expect(brain.station, isNotNull);
    // (The rest, him plugging in and out, is the brain's: its tests.)
    expect(words(), isNot(contains("HE'S BUSY, A MOMENT")));
  });
}
