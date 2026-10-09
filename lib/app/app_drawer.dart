import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/pages/backup/backup.dart';
import 'package:the_app/pages/security/security.dart';
import 'package:the_app/pages/settings/settings.dart';
import 'package:the_app/pages/settings/themes.dart';
import 'package:the_app/providers/session_provider.dart';

/// The hamburger menu: app-wide pages, with the app version at the bottom.
class AppDrawer extends ConsumerWidget {
  const AppDrawer({super.key});

  /// Closes the drawer, then opens [page] on top of the current section, so
  /// back returns to that section.
  void _open(BuildContext context, Widget page) {
    Scaffold.of(context).closeDrawer();
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => page));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Drawer(
      backgroundColor: context.colors.surface,
      child: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(16, 24, 16, 16),
              child: Text(
                'The App',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Divider(height: 1, color: context.colors.divider),
            if (ref.watch(sessionProvider) != null)
              ListTile(
                leading: const Icon(Icons.lock_outline),
                title: const Text('Lock now'),
                onTap: () {
                  ref.read(sessionProvider.notifier).lock();
                  Scaffold.of(context).closeDrawer();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Locked')),
                  );
                },
              ),
            ListTile(
              leading: const Icon(Icons.shield_outlined),
              title: const Text('Security'),
              onTap: () => _open(context, const SecurityPage()),
            ),
            ListTile(
              leading: const Icon(Icons.save_alt),
              title: const Text('Backup'),
              onTap: () => _open(context, const BackupPage()),
            ),
            ListTile(
              leading: const Icon(Icons.palette_outlined),
              title: const Text('Themes'),
              onTap: () => _open(context, const ThemesPage()),
            ),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Settings'),
              onTap: () => _open(context, const SettingsPage()),
            ),
            const Spacer(),
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
