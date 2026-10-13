import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/routes.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/pages/backup/backup.dart';
import 'package:the_app/pages/notifications/notifications.dart';
import 'package:the_app/pages/security/security.dart';
import 'package:the_app/pages/settings/settings.dart';
import 'package:the_app/pages/settings/themes.dart';
import 'package:the_app/providers/backup_reminder_provider.dart';
import 'package:the_app/providers/pip_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/widgets/pip.dart';
import 'package:the_app/widgets/pip_room.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// The hamburger menu: app-wide pages, with the app version at the bottom.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  /// Opens [page] on top, with the menu left open behind it (G16): back
  /// returns to the menu, and back again closes it.
  void _open(BuildContext context, Widget page) {
    Navigator.of(context).push(
      MaterialPageRoute(
        settings: const RouteSettings(name: AppRoutes.menuPage),
        builder: (_) => page,
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: context.colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // A fixed header with the special actions (doesn't scroll),
            // always the same height, Lock now or not (Round 25), with Pip.
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 8, 8),
              child: SizedBox(
                key: const Key('menuHeader'),
                height: kMinInteractiveDimension,
                child: Row(
                  children: [
                    const Pip(key: Key('menuPip'), size: 32),
                    const SizedBox(width: 12),
                    Expanded(
                      // A little lower than centred, level with Pip's head
                      // and feet rather than his antenna (Round 27).
                      child: Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(
                          key: const Key('menuTitle'),
                          'The App',
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                    if (ref.watch(sessionProvider) != null)
                      IconButton(
                        icon: const Icon(Icons.lock_outline),
                        tooltip: 'Lock now',
                        // Quietly (Round 24): the menu stays open, so the
                        // page behind it isn't shown; the button going
                        // away says it's done.
                        onPressed: ref.read(sessionProvider.notifier).lock,
                      ),
                  ],
                ),
              ),
            ),
            Divider(height: 1, color: context.colors.divider),
            // The items can be pulled down into thumb reach (reach mode).
            Expanded(
              child: PullDownList.children(
                children: [
                  ListTile(
                    leading: const Icon(Icons.shield_outlined),
                    title: const Text('Security'),
                    onTap: () => _open(context, const SecurityPage()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.palette_outlined),
                    title: const Text('Themes'),
                    onTap: () => _open(context, const ThemesPage()),
                  ),
                  ListTile(
                    leading: ref.watch(backupDueProvider)
                        ? Badge(
                            key: const Key('backupDot'),
                            smallSize: 10,
                            backgroundColor: context.colors.danger,
                            child: const Icon(Icons.save_alt),
                          )
                        : const Icon(Icons.save_alt),
                    title: const Text('Backup'),
                    subtitle: ref.watch(backupDueProvider)
                        ? Text(
                            'Time for a new one',
                            style:
                                TextStyle(color: context.colors.textSecondary),
                          )
                        : null,
                    onTap: () => _open(context, const BackupPage()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.notifications_outlined),
                    title: const Text('Notifications'),
                    onTap: () => _open(context, const NotificationsPage()),
                  ),
                  ListTile(
                    leading: const Icon(Icons.settings_outlined),
                    title: const Text('Settings'),
                    onTap: () => _open(context, const SettingsPage()),
                  ),
                ],
              ),
            ),
            // Pip's room (Round 26).
            PipRoom(
              brain: ref.watch(pipBrainProvider),
              animate: ref.watch(pipAnimatesProvider),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                'Version ${ref.watch(appVersionProvider)}',
                style: TextStyle(
                  color: context.colors.textMuted,
                  fontSize: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
