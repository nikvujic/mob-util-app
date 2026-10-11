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
    expect(assets, ['assets/icons/counters.svg', 'assets/icons/dzoni.svg']);
    for (final asset in assets) {
      final svg = await tester.runAsync(() => rootBundle.loadString(asset));
      expect(svg, contains('<svg'), reason: asset);
    }
    expect(find.byTooltip('Counters'), findsOneWidget);
    expect(find.byTooltip('Džoni'), findsOneWidget);
  });
}
