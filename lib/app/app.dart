import 'package:flutter/material.dart';
import 'package:the_app/app/app_drawer.dart';
import 'package:the_app/app/bottom_nav.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/pages/notes/notes.dart';
import 'package:the_app/pages/other/other.dart';
import 'package:the_app/pages/planner/planner.dart';
import 'package:the_app/pages/shop/shop.dart';

/// The app shell: theme and the home screen with the main sections.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'The App',
      theme: AppTheme.dark,
      home: const HomeScreen(),
    );
  }
}

/// Bottom navigation between the main sections, plus the app menu.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _pages = [NotesPage(), ShopPage(), PlannerPage(), OtherPage()];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      drawer: const AppDrawer(),
      // Every section is the bottom of the navigation stack: back on any of
      // them leaves the app, and pages opened from a section are pushed on
      // top. IndexedStack keeps every tab alive so scroll position and
      // selection survive switching tabs; TickerMode marks the visible one.
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (var i = 0; i < _pages.length; i++)
            TickerMode(enabled: i == _selectedIndex, child: _pages[i]),
        ],
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) => setState(() => _selectedIndex = index),
      ),
    );
  }
}
