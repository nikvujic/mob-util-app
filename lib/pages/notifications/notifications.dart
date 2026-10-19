import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/sound.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/notification_log.dart';
import 'package:the_app/models/notification_target.dart';
import 'package:the_app/models/notify_settings.dart';
import 'package:the_app/providers/notification_log_provider.dart';
import 'package:the_app/providers/notification_target_provider.dart';
import 'package:the_app/providers/planner_provider.dart' show isSameDay;
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/reminders_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/colour_choice.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// How long a pause lasts: through today and this many days more.
const pauseChoices = <(String, int)>[
  ('Today', 0),
  ('Through tomorrow', 1),
  ('3 days', 2),
  ('A week', 6),
];

/// Makes sure notifications may be shown, asking Android if needed, and
/// says so if not (O13).
Future<void> allowNotifications(BuildContext context, WidgetRef ref) async {
  final messenger = ScaffoldMessenger.of(context);
  if (await ref.read(reminderPlannerProvider).requestPermission()) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text(
          'Notifications are off for this app, so reminders won\'t show. '
          'They can be turned on in Android\'s settings.',
        ),
      ),
    );
}

/// Only while the phone blocks them: reminders can't show (E1).
class NotificationsOffTile extends ConsumerWidget {
  const NotificationsOffTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (ref.watch(notificationsAllowedProvider).valueOrNull != false) {
      return const SizedBox.shrink();
    }
    return ListTile(
      key: const Key('notificationsOff'),
      leading: Icon(
        Icons.notifications_off_outlined,
        color: context.colors.danger,
      ),
      title: const Text('Notifications are off'),
      subtitle: Text(
        "Reminders can't show. Tap to allow them, or allow them for "
        "The App in the phone's settings.",
        style: TextStyle(color: context.colors.textSecondary),
      ),
      onTap: () async {
        await ref.read(reminderPlannerProvider).requestPermission();
        ref.invalidate(notificationsAllowedProvider);
      },
    );
  }
}

/// A kind of notification's icon.
IconData _iconOf(String kind) => switch (kind) {
      'planner' => Icons.calendar_today_outlined,
      'medicine' => Icons.medication_outlined,
      'backup' => Icons.save_alt,
      _ => Icons.info_outline,
    };

/// "Today 10:05", "Yesterday 18:00".
String _when(DateTime at, DateTime now) =>
    '${isSameDay(at, now) ? 'Today' : 'Yesterday'} '
    '${formatMinutes(at.hour * 60 + at.minute)}';

/// Goes where [n] leads, as tapping the notification would (from the
/// home screen, over everything).
void _open(WidgetRef ref, LoggedNotification n) {
  final target = NotificationTarget.parse(n.target);
  if (target != null) ref.read(pendingTargetProvider.notifier).state = target;
}

/// One notification of the history.
class _Entry extends ConsumerWidget {
  final LoggedNotification n;

  const _Entry(this.n);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final now = ref.watch(clockProvider)();
    return ListTile(
      leading: Icon(_iconOf(n.kind), color: colors.accent),
      title: Text(n.title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${_when(n.at, now)} · ${n.body}',
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(color: colors.textSecondary),
      ),
      onTap: n.target == null ? null : () => _open(ref, n),
    );
  }
}

/// The Notifications page (Round 31; menu → Notifications): the latest
/// ones (all of today's and yesterday's a tap away), then each page's
/// settings.
class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  /// How many of the latest show in the window.
  static const recent = 3;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final now = ref.watch(clockProvider)();
    final history = ref.watch(notificationLogProvider).historyAt(now);
    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: PullDownList.children(
        children: [
          const NotificationsOffTile(),
          Card(
            key: const Key('recentNotifications'),
            margin: const EdgeInsets.fromLTRB(12, 8, 12, 8),
            color: colors.card,
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  title: Text(
                    'RECENT',
                    // Not the accent: too faint on the card in some themes.
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1,
                    ),
                  ),
                  trailing: history.isEmpty
                      ? null
                      : TextButton(
                          onPressed: () => Navigator.of(context).push(
                            MaterialPageRoute<void>(
                              builder: (_) => const NotificationHistoryPage(),
                            ),
                          ),
                          child: Text('All ${history.length}'),
                        ),
                ),
                if (history.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    child: Text(
                      'None today or yesterday',
                      style: TextStyle(color: colors.textMuted),
                    ),
                  ),
                for (final n in history.take(recent)) _Entry(n),
              ],
            ),
          ),
          for (final page in NotifyPage.values) _PageSettings(page),
        ],
      ),
    );
  }
}

/// One page's notification settings.
class _PageSettings extends ConsumerWidget {
  final NotifyPage page;

  const _PageSettings(this.page);

  Future<int?> _pickPause(BuildContext context, {required bool paused}) =>
      showModalBottomSheet<int>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  paused ? 'Paused' : 'Pause',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              for (final (label, days) in pauseChoices)
                ListTile(
                  title: Text(label),
                  onTap: () => Navigator.of(context).pop(days),
                ),
              if (paused)
                ListTile(
                  title: const Text('Resume now'),
                  onTap: () => Navigator.of(context).pop(-1),
                ),
            ],
          ),
        ),
      );

  /// The sounds to pick from; each the app has its own of plays when
  /// tapped, and picking closes the sheet.
  Future<NotifySound?> _pickSound(
    BuildContext context,
    NotifySound now,
    NotifyVolume volume,
  ) =>
      showModalBottomSheet<NotifySound>(
        context: context,
        builder: (context) => SafeArea(
          // Round 39: more sounds than a short screen holds: it scrolls.
          child: ListView(
            key: const Key('notifySounds'),
            shrinkWrap: true,
            children: [
              const ListTile(
                title: Text(
                  'Sound',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              for (final sound in NotifySound.values)
                ListTile(
                  title: Text(sound.label),
                  selected: sound == now,
                  trailing: sound == now ? const Icon(Icons.check) : null,
                  onTap: () {
                    if (sound.resource case final resource?) {
                      AppSound.notify(resource, volume: volume.level);
                    }
                    Navigator.of(context).pop(sound);
                  },
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final preferences = ref.watch(preferencesProvider);
    final notifier = ref.read(preferencesProvider.notifier);
    final today = dayOf(ref.watch(clockProvider)());
    final style = preferences.styleOf(page);
    TextStyle muted() => TextStyle(color: colors.textSecondary);

    final (on, about) = switch (page) {
      NotifyPage.planner => (
          preferences.plannerReminders,
          'Before blocks that have a reminder, and the planner\'s own '
              'reminders.',
        ),
      NotifyPage.medicine => (
          preferences.medicineReminders,
          'At each dose time not yet marked (and again later, if a '
              'medicine is set to).',
        ),
      NotifyPage.backup => (
          preferences.backupReminder,
          'When a week has gone by without a backup (with a dot on the '
              'menu).',
        ),
      NotifyPage.dates => (
          preferences.datesReminders,
          'Before birthdays and dates, as each one is set to remind.',
        ),
    };
    final pausedUntil = switch (page) {
      NotifyPage.planner => preferences.plannerPausedUntil,
      NotifyPage.medicine => preferences.medicinePausedUntil,
      NotifyPage.backup => null,
      NotifyPage.dates => preferences.datesPausedUntil,
    };
    final paused = pausedUntil != null && !today.isAfter(pausedUntil);

    return Column(
      key: Key('notify-${page.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            page.label.toUpperCase(),
            style: TextStyle(
              color: colors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
        SwitchListTile(
          key: Key('notifyOn-${page.name}'),
          secondary: const Icon(Icons.notifications_outlined),
          title: const Text('Notifications'),
          subtitle: Text(about, style: muted()),
          value: on,
          onChanged: (on) {
            switch (page) {
              case NotifyPage.planner:
                notifier.setPlannerReminders(on);
              case NotifyPage.medicine:
                notifier.setMedicineReminders(on);
              case NotifyPage.backup:
                notifier.setBackupReminder(on);
              case NotifyPage.dates:
                notifier.setDatesReminders(on);
            }
            if (on) allowNotifications(context, ref);
          },
        ),
        if (on) ...[
          // Round 72: the planner's notification that stays.
          if (page == NotifyPage.planner)
            SwitchListTile(
              key: const Key('notifyNow-planner'),
              secondary: const Icon(Icons.push_pin_outlined),
              title: const Text('While a block is on'),
              subtitle: Text(
                'A quiet notification that stays till it ends, counting '
                'down, with Done to tick it off (routines too).',
                style: muted(),
              ),
              value: preferences.plannerNow,
              onChanged: notifier.setPlannerNow,
            ),
          if (page != NotifyPage.backup)
            ListTile(
              key: Key('notifyPause-${page.name}'),
              leading: Icon(
                paused ? Icons.play_circle_outline : Icons.pause_circle_outline,
              ),
              title: Text(paused ? 'Paused' : 'Pause'),
              subtitle: Text(
                paused
                    ? 'None through ${formatDay(pausedUntil, today: today)}'
                        '${page == NotifyPage.medicine ? ' (nor the dot)' : ''}'
                    : 'For a day or more'
                        '${page == NotifyPage.medicine ? ' (the dot too)' : ''}',
                style: muted(),
              ),
              onTap: () async {
                final picked = await _pickPause(context, paused: paused);
                if (picked == null) return;
                final until = picked < 0 ? null : addDays(today, picked);
                switch (page) {
                  case NotifyPage.planner:
                    notifier.pausePlannerUntil(until);
                  case NotifyPage.medicine:
                    notifier.pauseMedicineUntil(until);
                  case NotifyPage.dates:
                    notifier.pauseDatesUntil(until);
                  case NotifyPage.backup:
                }
              },
            ),
          if (page != NotifyPage.backup)
            SwitchListTile(
              key: Key('notifyPrivate-${page.name}'),
              secondary: const Icon(Icons.visibility_off_outlined),
              title: const Text('Private'),
              subtitle: Text(
                switch (page) {
                  NotifyPage.planner =>
                    'Without names: "A block starts at 10:00"',
                  NotifyPage.dates => 'Without names: "A birthday tomorrow"',
                  _ => 'Without names: "A dose is due at 08:00"',
                },
                style: muted(),
              ),
              value: style.private,
              onChanged: (private) => notifier.setNotifyStyle(
                page,
                style.copyWith(private: private),
              ),
            ),
          ListTile(
            key: Key('notifySound-${page.name}'),
            leading: Icon(
              style.sound == NotifySound.silent
                  ? Icons.volume_off_outlined
                  : Icons.volume_up_outlined,
            ),
            title: const Text('Sound'),
            subtitle: Text(style.sound.label, style: muted()),
            onTap: () async {
              final picked =
                  await _pickSound(context, style.sound, style.volume);
              if (picked == null) return;
              notifier.setNotifyStyle(page, style.copyWith(sound: picked));
            },
          ),
          // How loud (Round 41): the app's own sounds only (the phone's
          // follows the phone's volume).
          if (style.sound.resource case final resource?)
            Padding(
              padding: const EdgeInsets.fromLTRB(72, 0, 16, 8),
              child: Wrap(
                spacing: 8,
                children: [
                  for (final volume in NotifyVolume.values)
                    ChoiceChip(
                      key: Key('notifyVolume-${page.name}-${volume.name}'),
                      label: Text(volume.label),
                      selected: style.volume == volume,
                      onSelected: (_) {
                        AppSound.notify(resource, volume: volume.level);
                        notifier.setNotifyStyle(
                          page,
                          style.copyWith(volume: volume),
                        );
                      },
                    ),
                ],
              ),
            ),
          ListTile(
            leading: const Icon(Icons.palette_outlined),
            title: const Text('Colour'),
            subtitle: Text(
              style.colour == null ? "The phone's own" : 'Its icon tinted',
              style: muted(),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: ColourChoice(
              key: Key('notifyColour-${page.name}'),
              selected: BlockColor.fromName(style.colour),
              onSelected: (colour) => notifier.setNotifyStyle(
                page,
                style.copyWith(colour: () => colour?.name),
              ),
            ),
          ),
        ],
        const Divider(),
      ],
    );
  }
}

/// All of today's and yesterday's notifications (Round 31), newest
/// first; tapping one goes where it leads; *Clear* empties the list.
class NotificationHistoryPage extends ConsumerWidget {
  const NotificationHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final now = ref.watch(clockProvider)();
    final history = ref.watch(notificationLogProvider).historyAt(now);
    final colors = context.colors;
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            text.toUpperCase(),
            style: TextStyle(
              color: colors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        );
    final today = [
      for (final n in history)
        if (isSameDay(n.at, now)) n,
    ];
    final yesterday = [
      for (final n in history)
        if (!isSameDay(n.at, now)) n,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Recent notifications')),
      body: history.isEmpty
          ? Center(
              child: Text(
                'None today or yesterday',
                style: TextStyle(color: colors.textSecondary),
              ),
            )
          : PullDownList.children(
              bottomSpace: BottomActions.contentClearance,
              children: [
                if (today.isNotEmpty) header('Today'),
                for (final n in today) _Entry(n),
                if (yesterday.isNotEmpty) header('Yesterday'),
                for (final n in yesterday) _Entry(n),
              ],
            ),
      floatingActionButton: BottomActions(
        actions: [
          BottomAction(
            icon: Icons.clear_all,
            tooltip: 'Clear',
            enabled: history.isNotEmpty,
            onPressed: () {
              final log = ref.read(notificationLogProvider.notifier);
              final before = log.clear(now);
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: const Text('Cleared'),
                    action: SnackBarAction(
                      label: 'Undo',
                      onPressed: () => log.unclear(before),
                    ),
                  ),
                );
            },
          ),
        ],
      ),
    );
  }
}
