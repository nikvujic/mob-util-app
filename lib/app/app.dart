import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/app/app_drawer.dart';
import 'package:the_app/app/bottom_nav.dart';
import 'package:the_app/app/privacy_curtain.dart';
import 'package:the_app/app/section_gate.dart';
import 'package:the_app/core/routes.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/pages/notes/notes.dart';
import 'package:the_app/pages/hub/hub.dart';
import 'package:the_app/pages/planner/planner.dart';
import 'package:the_app/pages/security/password_form.dart';
import 'package:the_app/pages/shop/shop.dart';
import 'package:the_app/providers/fingerprint_provider.dart';
import 'package:the_app/providers/hub_dots_provider.dart';
import 'package:the_app/models/notification_target.dart';
import 'package:the_app/providers/medicine_alerts_provider.dart';
import 'package:the_app/providers/notification_target_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/reminders_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/providers/storage_status_provider.dart';
import 'package:the_app/widgets/app_dialog.dart';
import 'package:the_app/widgets/back_handlers.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/section_reset.dart';

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
      // Tracks which side the user touches, for G11 bottom actions; the
      // curtain hides what's unlocked as the app leaves.
      builder: (context, child) =>
          PrivacyCurtain(child: HandTracker(child: child!)),
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
  static const _pages = [NotesPage(), ShopPage(), PlannerPage(), HubPage()];

  /// How far a swipe right along the bottom bar must go to open the menu.
  static const menuSwipeDistance = 48.0;

  /// Distance of the current swipe along the bottom bar.
  double _menuSwipe = 0;

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

  /// Looks again whether a dose has come due (the red dot, O13).
  late final Timer _doseCheck = Timer.periodic(
    const Duration(seconds: 30),
    (_) => ref.invalidate(medicineDotProvider),
  );

  /// Tells the session when the app leaves and comes back, for auto-lock.
  late final AppLifecycleListener _lifecycle = AppLifecycleListener(
    onHide: () => ref.read(sessionProvider.notifier).appHidden(),
    onShow: () {
      ref.read(sessionProvider.notifier).appShown();
      // A dose may have come due while away (O13).
      ref.invalidate(medicineDotProvider);
      // Reminders are planned two weeks ahead: top them up (P10).
      ref.read(reminderPlannerProvider).refresh();
    },
  );

  @override
  void initState() {
    super.initState();
    _lifecycle; // start listening
    _doseCheck; // start looking
    WidgetsBinding.instance.addPostFrameCallback((_) => _tellUnreadable());
  }

  /// Says so if some data couldn't be read at startup (the app started
  /// without it, keeping the file aside rather than overwriting it).
  void _tellUnreadable() {
    final files = ref.read(unreadableFilesProvider);
    if (files.isEmpty || !mounted) return;
    showDialog<void>(
      context: context,
      builder: (context) => AppDialog(
        title: "Some data couldn't be read",
        content: DialogMessage(
          '${files.join(', ')} could not be read, so the app started '
          'without ${files.length == 1 ? 'it' : 'them'}. The file was kept '
          "aside, not overwritten. Restoring a backup brings the data back.",
        ),
        actions: [
          DialogButton(
            label: 'OK',
            primary: true,
            onPressed: () => Navigator.of(context).pop(),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    for (final signal in _sectionShown) {
      signal.dispose();
    }
    _lifecycle.dispose();
    _exitArmed?.cancel();
    _doseCheck.cancel();
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

  /// Goes to [section], as its tab in the bottom bar does: both the
  /// section left and the one shown reset (G13, G18).
  void _show(AppSection section) {
    final index = AppSection.values.indexOf(section);
    final left = _selectedIndex;
    setState(() => _selectedIndex = index);
    if (left != index) _sectionShown[left].fire();
    _sectionShown[index].fire();
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

    // Kept running, so changing the master password turns fingerprint
    // unlock off at once (L6).
    ref.listen(fingerprintProvider, (_, __) {});
    // Kept running, so reminders follow every planner change (P10).
    ref.listen(reminderPlannerProvider, (_, __) {});
    // A notification tapped: to its section, on top of everything (its
    // page takes it from there once unlocked, Round 19).
    ref.listen(notificationOpenerProvider, (_, __) {});
    ref.listen(pendingTargetProvider, (_, target) {
      if (target == null) return;
      Navigator.of(context).popUntil((route) => route.isFirst);
      _show(switch (target) {
        PlannerTarget() => AppSection.planner,
        MedicineTarget() => AppSection.hub,
      });
    });

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
      // opened from a section are pushed on top. IndexedStack keeps every
      // tab alive; TickerMode marks the visible one. Switching tabs resets
      // both the section left and the one shown (SectionReset): lists to
      // their top, selection off, the planner on today (G13, G18).
      body: IndexedStack(
        index: _selectedIndex,
        children: [
          for (var i = 0; i < _pages.length; i++)
            TickerMode(
              enabled: i == _selectedIndex,
              child: SectionReset(
                signal: _sectionShown[i],
                child: SectionGate(
                  section: AppSection.values[i],
                  child: _pages[i],
                ),
              ),
            ),
        ],
      ),
      // Swiping right along the bottom bar opens the menu: easier to reach
      // with the right thumb than the left edge of the screen.
      bottomNavigationBar: GestureDetector(
        onHorizontalDragStart: (_) => _menuSwipe = 0,
        onHorizontalDragUpdate: (d) => _menuSwipe += d.primaryDelta ?? 0,
        onHorizontalDragEnd: (d) {
          if (_menuSwipe > menuSwipeDistance ||
              (d.primaryVelocity ?? 0) > 300) {
            _scaffold.currentState?.openDrawer();
          }
        },
        child: BottomNav(
          selectedIndex: _selectedIndex,
          hubDot: ref.watch(hubDotProvider),
          onItemTapped: (index) => _show(AppSection.values[index]),
        ),
      ),
    );
  }
}

/// A bare "it happened" signal.
class _Signal extends ChangeNotifier {
  void fire() => notifyListeners();
}
