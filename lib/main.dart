import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/pages/notes/notes.dart';
import 'package:the_app/pages/shop/shop.dart';
import 'package:the_app/pages/todo/todo.dart';
import 'package:the_app/widgets/bottom_nav.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // File storage is not available in the browser; the web build is only
  // used for previews.
  final storage = kIsWeb ? AppStorage.inMemory() : await AppStorage.open();
  runApp(
    ProviderScope(
      overrides: [appStorageProvider.overrideWithValue(storage)],
      child: const MyApp(),
    ),
  );
}

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

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const _pages = [NotesPage(), ShopPage(), TodoPage()];

  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // IndexedStack keeps every tab alive so scroll position and selection
      // survive switching tabs. TickerMode marks which tab is visible.
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
