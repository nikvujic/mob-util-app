import 'package:flutter/material.dart';

/// App bar for the main sections (the bottom-navigation tabs): the section
/// title and the hamburger button that opens the app menu.
class MainAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const MainAppBar({super.key, required this.title});

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      // The menu belongs to the home screen's outer Scaffold (so it covers
      // the bottom navigation), not to this section's own Scaffold.
      leading: IconButton(
        icon: const Icon(Icons.menu),
        tooltip: 'Menu',
        onPressed: () =>
            context.findRootAncestorStateOfType<ScaffoldState>()?.openDrawer(),
      ),
      title: Text(title),
    );
  }
}
