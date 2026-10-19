import 'package:the_app/models/notify_settings.dart';
import 'package:the_app/pages/hub/clears_shown.dart';
import 'package:flutter/widgets.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/pages/hub/counters.dart';
import 'package:the_app/pages/hub/dates.dart';
import 'package:the_app/pages/hub/food.dart';
import 'package:the_app/pages/hub/medicine.dart';
import 'package:the_app/pages/hub/pip_home.dart';
import 'package:the_app/pages/hub/placard.dart';
import 'package:the_app/pages/hub/recipes.dart';
import 'package:the_app/pages/hub/subscriptions.dart';

/// How each of the Hub's pages (O9) looks and opens. Exhaustive: a new
/// [HubTool] doesn't compile until it's here.
extension HubToolPage on HubTool {
  /// An SVG asset drawn in black, shown in the accent colour.
  String get icon => switch (this) {
        HubTool.counters => 'assets/icons/counters.svg',
        HubTool.placard => 'assets/icons/placard.svg',
        HubTool.medicine => 'assets/icons/medicine.svg',
        HubTool.recipes => 'assets/icons/recipes.svg',
        HubTool.food => 'assets/icons/food.svg',
        HubTool.dates => 'assets/icons/dates.svg',
        HubTool.subscriptions => 'assets/icons/subscriptions.svg',
        HubTool.pip => 'assets/icons/pip.svg',
      };

  Widget page() => switch (this) {
        HubTool.counters => const CountersPage(),
        HubTool.placard => const PlacardPage(),
        // Round 61: opened, their shown notifications go.
        HubTool.medicine =>
          const ClearsShown(page: NotifyPage.medicine, child: MedicinePage()),
        HubTool.recipes => const RecipesPage(),
        HubTool.food => const FoodPage(),
        HubTool.dates =>
          const ClearsShown(page: NotifyPage.dates, child: DatesPage()),
        HubTool.subscriptions => const ClearsShown(
            page: NotifyPage.subscriptions, child: SubscriptionsPage()),
        HubTool.pip => const PipHomePage(),
      };
}
