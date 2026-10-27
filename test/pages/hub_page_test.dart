import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/providers/layout_provider.dart';

import '../helpers.dart';

/// The Other page (O1–O3): a tile per tool, with its own icon.
void main() {
  testWidgets('each tile has its own icon, which is in the app',
      (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Hub');

    final assets = [
      for (final picture
          in tester.widgetList<SvgPicture>(find.byType(SvgPicture)))
        (picture.bytesLoader as SvgAssetLoader).assetName,
    ];
    expect(assets.toSet(), {
      'assets/icons/counters.svg',
      'assets/icons/placard.svg',
      'assets/icons/medicine.svg',
      'assets/icons/recipes.svg', // Round 42
      'assets/icons/food.svg', // Round 46
      'assets/icons/dates.svg', // Round 57
      'assets/icons/subscriptions.svg', // Round 79
      'assets/icons/spotify.svg', // Round 93
      'assets/icons/packing.svg', // Round 94
      'assets/icons/pip.svg', // hatched (Round 35)
    });
    expect(assets.toSet().length, assets.length, reason: 'each its own');
    for (final asset in assets) {
      final svg = await tester.runAsync(() => rootBundle.loadString(asset));
      expect(svg, contains('<svg'), reason: asset);
    }
    expect(find.byTooltip('Counters'), findsOneWidget);
  });

  testWidgets('tools are icon tiles, the first one in the bottom right',
      (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Hub');

    final size = tester.getSize(find.byType(MaterialApp));
    final counters = tester.getRect(find.byTooltip('Counters'));
    expect(counters.width, counters.height, reason: 'square');
    expect(counters.center.dx, greaterThan(size.width * 0.8));
    expect(counters.center.dy, greaterThan(size.height * 0.6));
    expect(find.text('Counters'), findsNothing, reason: 'no titles');
    final placard = tester.getRect(find.byTooltip('Placard'));
    expect(placard.center.dx, lessThan(counters.center.dx),
        reason: 'next, leftwards');
  });

  test("the default order (Round 48, the user's)", () {
    expect(PageLayout.initial.hub, [
      HubTool.counters,
      HubTool.medicine,
      HubTool.placard,
      HubTool.pip,
      HubTool.recipes,
      HubTool.food,
      HubTool.dates,
      HubTool.subscriptions, // Round 79
      HubTool.spotify, // Round 93
      HubTool.packing, // Round 94
    ]);
  });

  group('arranging (O8)', () {
    testWidgets('hold a tile and drag it onto another: they swap places',
        (tester) async {
      final container = await pumpApp(tester);
      await openTab(tester, 'Hub');
      final counters = tester.getCenter(find.byTooltip('Counters'));
      final placard = tester.getCenter(find.byTooltip('Placard'));

      final drag = await tester.startGesture(placard);
      await tester.pump(kLongPressTimeout + const Duration(milliseconds: 50));
      await drag.moveTo(Offset.lerp(placard, counters, 0.5)!);
      await tester.pump();
      await drag.moveTo(counters);
      await tester.pump();
      await drag.up();
      await tester.pumpAndSettle();

      expect(container.read(layoutProvider).hub, [
        HubTool.placard,
        HubTool.counters,
        HubTool.medicine,
        HubTool.pip,
        HubTool.recipes,
        HubTool.food,
        HubTool.dates,
        HubTool.subscriptions,
        HubTool.spotify,
        HubTool.packing,
      ]);
      expect(
        tester.getCenter(find.byTooltip('Placard')).dx,
        moreOrLessEquals(counters.dx, epsilon: 1),
        reason: 'now in the bottom right',
      );
    });

    testWidgets('a tap still opens the page', (tester) async {
      await pumpApp(tester);
      await openTab(tester, 'Hub');
      await tester.tap(find.byTooltip('Counters'));
      await tester.pumpAndSettle();
      expect(appBarTitle('Counters'), findsOneWidget);
    });

    testWidgets('screen readers can move tiles too', (tester) async {
      final semantics = tester.ensureSemantics();
      final container = await pumpApp(tester);
      await openTab(tester, 'Hub');
      final node = tester.getSemantics(find.byTooltip('Counters'));
      final owner = node.owner!;
      final later = CustomSemanticsAction.getIdentifier(
        const CustomSemanticsAction(label: 'Move later'),
      );
      owner.performAction(node.id, SemanticsAction.customAction, later);
      await tester.pump();
      expect(container.read(layoutProvider).hub, [
        HubTool.medicine,
        HubTool.counters,
        HubTool.placard,
        HubTool.pip,
        HubTool.recipes,
        HubTool.food,
        HubTool.dates,
        HubTool.subscriptions,
        HubTool.spotify,
        HubTool.packing,
      ]);
      semantics.dispose();
    });
  });

  group("Pip's home (Round 35)", () {
    testWidgets('only once he has hatched', (tester) async {
      await pumpApp(tester, pipHatched: false);
      await openTab(tester, 'Hub');
      expect(find.byTooltip('Pip'), findsNothing);
      expect(find.byTooltip('Counters'), findsOneWidget);
    });

    testWidgets('hidden, he keeps his place; the others still move right',
        (tester) async {
      final semantics = tester.ensureSemantics();
      final container = await pumpApp(tester, pipHatched: false);
      // Stored with him first (moved there before, say).
      container.read(layoutProvider.notifier).moveInHub(HubTool.pip, 0);
      await openTab(tester, 'Hub');
      final node = tester.getSemantics(find.byTooltip('Counters'));
      node.owner!.performAction(
        node.id,
        SemanticsAction.customAction,
        CustomSemanticsAction.getIdentifier(
          const CustomSemanticsAction(label: 'Move later'),
        ),
      );
      await tester.pump();
      expect(container.read(layoutProvider).hub, [
        HubTool.pip,
        HubTool.medicine,
        HubTool.counters,
        HubTool.placard,
        HubTool.recipes,
        HubTool.food,
        HubTool.dates,
        HubTool.subscriptions,
        HubTool.spotify,
        HubTool.packing,
      ]);
      semantics.dispose();
    });
  });
}
