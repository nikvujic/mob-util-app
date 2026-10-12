import 'package:flutter/widgets.dart';
import 'package:the_app/models/other_tool.dart';
import 'package:the_app/pages/other/counters.dart';
import 'package:the_app/pages/other/medicine.dart';
import 'package:the_app/pages/other/placard.dart';

/// How each of Other's pages (O9) looks and opens. Exhaustive: a new
/// [OtherTool] doesn't compile until it's here.
extension OtherToolPage on OtherTool {
  /// An SVG asset drawn in black, shown in the accent colour.
  String get icon => switch (this) {
        OtherTool.counters => 'assets/icons/counters.svg',
        OtherTool.placard => 'assets/icons/placard.svg',
        OtherTool.medicine => 'assets/icons/medicine.svg',
      };

  Widget page() => switch (this) {
        OtherTool.counters => const CountersPage(),
        OtherTool.placard => const PlacardPage(),
        OtherTool.medicine => const MedicinePage(),
      };
}
