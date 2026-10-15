import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';

class BottomNav extends StatelessWidget {
  final int selectedIndex;
  final ValueChanged<int> onItemTapped;

  /// A red dot on the Hub tab: one of its pages asks for attention (O13).
  final bool hubDot;

  /// A green one, without a red one (Round 57): something new to see.
  final bool hubNews;

  const BottomNav({
    super.key,
    required this.selectedIndex,
    required this.onItemTapped,
    this.hubDot = false,
    this.hubNews = false,
  });

  @override
  Widget build(BuildContext context) {
    Widget dotted(IconData icon) => hubDot
        ? Badge(
            key: const Key('hubDot'),
            smallSize: 9,
            backgroundColor: context.colors.danger,
            child: Semantics(label: 'Needs attention', child: Icon(icon)),
          )
        : hubNews
            ? Badge(
                key: const Key('hubNews'),
                smallSize: 9,
                backgroundColor: DateColours.seen,
                child: Semantics(label: 'Something new', child: Icon(icon)),
              )
            : Icon(icon);
    return BottomNavigationBar(
      currentIndex: selectedIndex,
      onTap: onItemTapped,
      items: [
        const BottomNavigationBarItem(
          icon: Icon(Icons.note_outlined),
          activeIcon: Icon(Icons.note),
          label: 'Notes',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.shopping_cart_outlined),
          activeIcon: Icon(Icons.shopping_cart),
          label: 'Shop',
        ),
        const BottomNavigationBarItem(
          icon: Icon(Icons.event_note_outlined),
          activeIcon: Icon(Icons.event_note),
          label: 'Planner',
        ),
        BottomNavigationBarItem(
          icon: dotted(Icons.apps_outlined),
          activeIcon: dotted(Icons.apps),
          label: 'Hub',
        ),
      ],
    );
  }
}
