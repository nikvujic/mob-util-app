import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/pages/settings/clear_data.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// Menu → Settings: small switches for how the app feels.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: PullDownList.children(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('Counter click and vibration'),
            subtitle: Text(
              'On − and +. The click follows the media volume.',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            value: preferences.counterFeedback,
            onChanged:
                ref.read(preferencesProvider.notifier).setCounterFeedback,
          ),
          SwitchListTile(
            secondary: const Icon(Icons.format_list_numbered),
            title: const Text('Line numbers in notes'),
            subtitle: Text(
              'One per paragraph, beside the text, like a code editor.',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            value: preferences.noteLineNumbers,
            onChanged:
                ref.read(preferencesProvider.notifier).setNoteLineNumbers,
          ),
          SwitchListTile(
            key: const Key('introOnUpdates'),
            secondary: const Icon(Icons.auto_stories_outlined),
            title: const Text('Introduction after updates'),
            subtitle: Text(
              'Brings the Introduction back to the top of Notes with each '
              'new version, showing what changed. It\'s always in the menu.',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            value: preferences.introOnUpdates,
            onChanged: ref.read(preferencesProvider.notifier).setIntroOnUpdates,
          ),
          const Divider(),
          ListTile(
            leading:
                Icon(Icons.delete_sweep_outlined, color: context.colors.danger),
            title: const Text('Clear data'),
            subtitle: Text(
              'Empty Notes, Shop, Planner or Hub pages',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const ClearDataPage()),
            ),
          ),
        ],
      ),
    );
  }
}
