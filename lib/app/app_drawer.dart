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
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/pip_adventure.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_scene.dart';
import 'package:the_app/providers/pip_life_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/widgets/pip.dart';
import 'package:the_app/widgets/pip_energy_bar.dart';
import 'package:the_app/widgets/pip_room.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/widgets/pixel_text.dart';
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
            // His name and age (Round 34), once he's hatched; on the right
            // his energy and the batteries held (Round 37).
            if (ref.watch(pipLifeProvider) case final pip when pip.hatched)
              Padding(
                key: const Key('pipNameAge'),
                // One of his pixels clear of his room below (Round 41).
                padding: const EdgeInsets.fromLTRB(
                  12,
                  8,
                  12,
                  PipRoom.smallPixel,
                ),
                child: Row(
                  children: [
                    // Round 63: out on his adventure, his level instead.
                    if (_adventureLevel(ref) case final level?)
                      PixelText(
                        [
                          (pip.name, PipColours.light),
                          ('  LV $level', context.colors.textSecondary),
                        ],
                        label: '${pip.name}, adventuring, level $level',
                      )
                    else
                      PixelText(
                        [
                          (pip.name, PipColours.light),
                          (
                            '  ${PipLife.ageText(pip.ageOn(ref.watch(clockProvider)())!)}',
                            context.colors.textSecondary,
                          ),
                        ],
                        label: '${pip.name}, '
                            '${PipLife.ageText(pip.ageOn(ref.watch(clockProvider)())!).toLowerCase()} old',
                      ),
                    const Spacer(),
                    PipEnergyBar(
                      key: const Key('pipEnergy'),
                      segments: ref
                          .read(pipLifeProvider.notifier)
                          .segmentsAt(ref.watch(clockProvider)()),
                      batteries: pip.batteries,
                    ),
                  ],
                ),
              ),
            // Pip's room (Round 26).
            PipRoom(
              brain: ref.watch(pipBrainProvider),
              animate: ref.watch(pipAnimatesProvider),
              // His energy, sleep and batteries (Round 37).
              link: ref.watch(pipLinkProvider),
              // His sky follows the time of day (Round 35).
              scene: PipScene.at(PipPlace.room, ref.watch(clockProvider)()),
              // Round 52: in the menu he may be thrown in by its swing.
              entrances: const {
                PipEntrance.ground,
                PipEntrance.sky,
                PipEntrance.side,
              },
              // Out of his egg: that's his birthday (Round 34).
              onHatched: () => ref
                  .read(pipLifeProvider.notifier)
                  .hatch(ref.read(clockProvider)()),
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

/// His level while he's out on his adventure (Round 63), or null.
int? _adventureLevel(WidgetRef ref) {
  final life = ref.read(pipLifeProvider.notifier);
  final now = ref.watch(clockProvider)();
  if (!life.outAt(now)) return null;
  return PipAdventure.levelFor(life.xpAt(now));
}
