import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/app/app_drawer.dart';
import 'package:the_app/app/bottom_nav.dart';
import 'package:the_app/app/section_gate.dart';
import 'package:the_app/core/routes.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/pages/notes/notes.dart';
import 'package:the_app/pages/other/other.dart';
import 'package:the_app/pages/planner/planner.dart';
import 'package:the_app/pages/security/password_form.dart';
import 'package:the_app/pages/shop/shop.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/widgets/back_handlers.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// The app shell: theme and the home screen with the main sections.
class MyApp extends ConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = AppThemeChoice.fromId(
      ref.watch(preferencesProvider.select((p) => p.theme)),
    );
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'The App',
      theme: AppTheme.of(theme.palette),
      // Switch themes at once: an animated switch showed the old colours
      // for a moment (Nikola saw the old theme flash on the next page).
      themeAnimationDuration: Duration.zero,
      // Tracks which side the user touches, for G11 bottom actions.
      builder: (context, child) => HandTracker(child: child!),
      home: const HomeScreen(),
      onGenerateRoute: _route,
    );
  }

  /// Pages features open by name (see [AppRoutes]). Typed, so callers get
  /// the page's result back as the right type.
  static Route<Object?>? _route(RouteSettings settings) {
    return switch (settings.name) {
      AppRoutes.setMasterPassword => MaterialPageRoute<String>(
          settings: settings,
          builder: (_) => const PasswordFormPage(mode: PasswordFormMode.set),
        ),
      _ => null,
    };
  }
}

/// Bottom navigation between the main sections, plus the app menu.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// The page of each section, in [AppSection] order.
  static const _pages = [NotesPage(), ShopPage(), PlannerPage(), OtherPage()];

  /// How long after a first back press a second one exits the app.
  static const exitWindow = Duration(seconds: 2);

  int _selectedIndex = 0;

  /// Fired when a section is gone to, so its lists drop any pulled-down
  /// space (G13).
  final _sectionShown = [for (final _ in _pages) _Signal()];

  /// Lets e.g. selection mode take back before the exit logic.
  final _backHandlers = BackHandlers();

  /// Running while a second back press would exit.
  Timer? _exitArmed;

  final _scaffold = GlobalKey<ScaffoldState>();

  /// Tells the session when the app leaves and comes back, for auto-lock.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onHide: () => ref.read(sessionProvider.notifier).appHidden(),
    onShow: () => ref.read(sessionProvider.notifier).appShown(),
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // start listening
  }

  @override
  void dispose() {
    for (final signal in _sectionShown) {
      signal.dispose();
    }
    _lifecycle.dispose();
    _exitArmed?.cancel();
    super.dispose();
  }

  /// System back on a main section: close the menu if it's open, else let
  /// the page use it (e.g. leave selection mode), else ask for a second
  /// press before exiting.
  void _onBack() {
    final scaffold = _scaffold.currentState;
    if (scaffold != null && scaffold.isDrawerOpen) {
      scaffold.closeDrawer();
      return;
    }
    if (_backHandlers.handle()) return;
    if (_exitArmed?.isActive ?? false) {
      SystemNavigator.pop();
      return;
    }
    _exitArmed = Timer(exitWindow, () {});
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Press back again to exit'),
          duration: exitWindow,
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    // The app locked while something was open on top of a locked section
    // (e.g. a note): close it, so nothing of the section stays visible.
    // Pages save when they're closed.
    ref.listen(
      sectionClosedProvider(AppSection.values[_selectedIndex]),
      (wasClosed, closed) {
        if (closed && wasClosed == false) {
          Navigator.of(context).popUntil((route) => route.isFirst);
        }
      },
    );

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: BackHandlerScope(
        handlers: _backHandlers,
        child: _buildScaffold(),
      ),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
      key: _scaffold,
      drawer: const AppDrawer(),
      // Every section is the bottom of the navigation stack: back on any of
      // them leaves the app (after a confirming second press), and pages
      // opened from a section are pushed on top. IndexedStack keeps every tab alive so scroll position and
      // selection survive switching tabs; TickerMode marks the visible one.
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (var i = 0; i < _pages.length; i++)
            TickerMode(
              enabled: i == _selectedIndex,
              child: PullDownReset(
                signal: _sectionShown[i],
                child: SectionGate(
                  section: AppSection.values[i],
                  child: _pages[i],
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: BottomNav(
        selectedIndex: _selectedIndex,
        onItemTapped: (index) {
          setState(() => _selectedIndex = index);
          _sectionShown[index].fire();
        },
      ),
    );
  }
}

/// A bare "it happened" signal.
class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}
