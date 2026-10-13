import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/reminders_provider.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// Makes sure notifications may be shown, asking Android if needed, and
/// says so if not (O13).
Future<void> allowMedicineReminders(
  BuildContext context,
  WidgetRef ref,
) async {
  final messenger = ScaffoldMessenger.of(context);
  if (await ref.read(reminderPlannerProvider).requestPermission()) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text(
          'Notifications are off for this app, so medicine reminders '
          'won\'t show. They can be turned on in Android\'s settings.',
        ),
      ),
    );
}

/// How long a pause lasts: through today and this many days more.
const _pauseChoices = <(String, int)>[
  ('Today', 0),
  ('Through tomorrow', 1),
  ('3 days', 2),
  ('A week', 6),
];

/// The Medicine page's settings (O12), from the gear in its top bar:
/// reminders at dose times (a second one is set per medicine, Round 16),
/// the red dot, and pausing both for a while.
class MedicineSettingsPage extends ConsumerWidget {
  const MedicineSettingsPage({super.key});

  Future<T?> _pick<T>(
    BuildContext context, {
    required String title,
    required List<(String, T)> choices,
    required bool Function(T) selected,
  }) =>
      showModalBottomSheet<T>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                title: Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
              for (final (label, value) in choices)
                ListTile(
                  title: Text(label),
                  selected: selected(value),
                  trailing: selected(value) ? const Icon(Icons.check) : null,
                  onTap: () => Navigator.of(context).pop(value),
                ),
            ],
          ),
        ),
      );

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    final notifier = ref.read(preferencesProvider.notifier);
    final today = dayOf(ref.watch(clockProvider)());
    final paused = preferences.medicinePausedOn(today);
    final colors = context.colors;
    TextStyle muted() => TextStyle(color: colors.textSecondary);

    return Scaffold(
      appBar: AppBar(title: const Text('Medicine settings')),
      body: PullDownList.children(
        children: [
          SwitchListTile(
            key: const Key('medicineReminders'),
            secondary: const Icon(Icons.notifications_outlined),
            title: const Text('Reminders'),
            subtitle: Text(
              'A notification at each dose time, unless you already set '
              'that dose as taken, missed or not sure. Each medicine can '
              'also remind again later (in its own settings).',
              style: muted(),
            ),
            value: preferences.medicineReminders,
            onChanged: (on) {
              notifier.setMedicineReminders(on);
              if (on) allowMedicineReminders(context, ref);
            },
          ),
          SwitchListTile(
            key: const Key('medicineDot'),
            secondary: const Icon(Icons.circle_notifications_outlined),
            title: const Text('Red dot'),
            subtitle: Text(
              'On the Medicine tile and the Hub tab while a dose is due '
              'and not marked. Shown even when the Hub is locked.',
              style: muted(),
            ),
            value: preferences.medicineDot,
            onChanged: notifier.setMedicineDot,
          ),
          const Divider(),
          ListTile(
            key: const Key('medicinePause'),
            leading: Icon(
              paused ? Icons.play_circle_outline : Icons.pause_circle_outline,
            ),
            title: Text(paused ? 'Paused' : 'Pause'),
            subtitle: Text(
              paused
                  ? 'No reminders or dot through '
                      '${formatDay(preferences.medicinePausedUntil!, today: today)}'
                  : 'Reminders and the dot, for a day or more',
              style: muted(),
            ),
            onTap: () async {
              final picked = await _pick<int>(
                context,
                title: paused ? 'Paused' : 'Pause',
                choices: [
                  ..._pauseChoices,
                  if (paused) ('Resume now', -1),
                ],
                selected: (days) =>
                    paused &&
                    days >= 0 &&
                    preferences.medicinePausedUntil == addDays(today, days),
              );
              if (picked == null) return;
              notifier.pauseMedicineUntil(
                picked < 0 ? null : addDays(today, picked),
              );
            },
          ),
        ],
      ),
    );
  }
}
