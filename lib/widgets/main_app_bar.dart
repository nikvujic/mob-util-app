import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

/// App bar for the main sections (the bottom-navigation tabs): the section
/// title and the hamburger button that opens the app menu.
class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  /// No actions (G11: they're at the bottom, on the hand's side).
  const MainAppBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // The menu belongs to the home screen's outer Scaffold (so it covers
      // the bottom navigation), not to this section's own Scaffold.
      leading: IconButton(
        icon: MenuDot.of(context)
            ? Badge(
                key: const Key('menuDot'),
                smallSize: 10,
                backgroundColor: context.colors.danger,
                child: const Icon(Icons.menu),
              )
            : const Icon(Icons.menu),
        tooltip: 'Menu',
        onPressed: () =>
            context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer(),
      ),
      title: Text(title),
    );
  }
}

/// Whether the menu has something waiting (a backup due, D8): a dot on
/// the menu button of every section. Set by the home screen.
class MenuDot extends InheritedWidget {
  final bool shown;

  const MenuDot({super.key, required this.shown, required super.child});

  static bool of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MenuDot>()?.shown ?? false;

  @override
  bool updateShouldNotify(MenuDot oldWidget) => shown != oldWidget.shown;
}
