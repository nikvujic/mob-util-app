import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/providers/dates_alerts_provider.dart';
import 'package:the_app/providers/medicine_alerts_provider.dart';
import 'package:the_app/providers/subscriptions_provider.dart';

/// Whether a Hub page asks for attention with a red dot on its tile (O13).
/// Exhaustive: a new [HubTool] doesn't compile until it's here.
final hubToolDotProvider = Provider.family<bool, HubTool>(
  (ref, tool) => switch (tool) {
    HubTool.counters => false,
    HubTool.placard => false,
    HubTool.medicine => ref.watch(medicineDotProvider),
    HubTool.recipes => false,
    HubTool.food => false,
    HubTool.dates => false,
    // Round 79: one to cancel soon (within its reminder).
    HubTool.subscriptions => ref.watch(subscriptionsDotProvider),
    HubTool.pip => false,
    HubTool.spotify => false,
    HubTool.packing => false,
  },
);

/// The red dot on the Hub tab: one of its pages has a dot. Shown even
/// while the Hub is locked (it tells nothing of what's inside).
final hubDotProvider = Provider<bool>(
  (ref) => HubTool.values.any((tool) => ref.watch(hubToolDotProvider(tool))),
);

/// Whether a Hub page has something new to see, with a green dot on its
/// tile (Round 57: a birthday today on Dates). Exhaustive like the red.
final hubToolNewsProvider = Provider.family<bool, HubTool>(
  (ref, tool) => switch (tool) {
    HubTool.dates => ref.watch(datesDotProvider),
    HubTool.counters ||
    HubTool.placard ||
    HubTool.medicine ||
    HubTool.recipes ||
    HubTool.food ||
    HubTool.subscriptions ||
    HubTool.pip ||
    HubTool.spotify ||
    HubTool.packing =>
      false,
  },
);

/// The green dot on the Hub tab: one of its pages has news (and none a
/// red dot: red wins).
final hubNewsProvider = Provider<bool>(
  (ref) => HubTool.values.any((tool) => ref.watch(hubToolNewsProvider(tool))),
);
