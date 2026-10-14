import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/providers/medicine_alerts_provider.dart';

/// Whether a Hub page asks for attention with a red dot on its tile (O13).
/// Exhaustive: a new [HubTool] doesn't compile until it's here.
final hubToolDotProvider = Provider.family<bool, HubTool>(
  (ref, tool) => switch (tool) {
    HubTool.counters => false,
    HubTool.placard => false,
    HubTool.medicine => ref.watch(medicineDotProvider),
    HubTool.recipes => false,
    HubTool.food => false,
    HubTool.pip => false,
  },
);

/// The red dot on the Hub tab: one of its pages has a dot. Shown even
/// while the Hub is locked (it tells nothing of what's inside).
final hubDotProvider = Provider<bool>(
  (ref) => HubTool.values.any((tool) => ref.watch(hubToolDotProvider(tool))),
);
