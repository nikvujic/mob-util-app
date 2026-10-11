import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

/// The Other page (O1–O3): a tile per tool, with its own icon.
void main() {
  testWidgets('each tile has its own icon, which is in the app',
      (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Other');

    final assets = [
      for (final picture
          in tester.widgetList<SvgPicture>(find.byType(SvgPicture)))
        (picture.bytesLoader as SvgAssetLoader).assetName,
    ];
    expect(assets, ['assets/icons/counters.svg']);
    for (final asset in assets) {
      final svg = await tester.runAsync(() => rootBundle.loadString(asset));
      expect(svg, contains('<svg'), reason: asset);
    }
    expect(find.byTooltip('Counters'), findsOneWidget);
  });

  testWidgets('tools are icon tiles, the first one in the bottom right',
      (tester) async {
    await pumpApp(tester);
    await openTab(tester, 'Other');

    final size = tester.getSize(find.byType(MaterialApp));
    final counters = tester.getRect(find.byTooltip('Counters'));
    expect(counters.width, counters.height, reason: 'square');
    expect(counters.center.dx, greaterThan(size.width * 0.8));
    expect(counters.center.dy, greaterThan(size.height * 0.6));
    expect(find.text('Counters'), findsNothing, reason: 'no titles');
  });
}
