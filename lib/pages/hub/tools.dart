import 'package:flutter/widgets.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/pages/hub/counters.dart';
import 'package:the_app/pages/hub/medicine.dart';
import 'package:the_app/pages/hub/placard.dart';

/// How each of the Hub's pages (O9) looks and opens. Exhaustive: a new
/// [HubTool] doesn't compile until it's here.
extension HubToolPage on HubTool {
  /// An SVG asset drawn in black, shown in the accent colour.
  String get icon => switch (this) {
        HubTool.counters => 'assets/icons/counters.svg',
        HubTool.placard => 'assets/icons/placard.svg',
        HubTool.medicine => 'assets/icons/medicine.svg',
      };

  Widget page() => switch (this) {
        HubTool.counters => const CountersPage(),
        HubTool.placard => const PlacardPage(),
        HubTool.medicine => const MedicinePage(),
      };
}
