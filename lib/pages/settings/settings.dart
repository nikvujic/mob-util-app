import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/pages/settings/clear_data.dart';
import 'package:the_app/providers/introduction_provider.dart';
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
          // The Introduction first, then the To-do note (Round 58).
          SwitchListTile(
            key: const Key('introOnUpdates'),
            secondary: const Icon(Icons.auto_stories_outlined),
            title: const Text('Introduction after updates'),
            subtitle: Text(
              'Brings the Introduction back to the top of Notes with each '
              'new version, showing what changed.',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            value: preferences.introOnUpdates,
            onChanged: ref.read(preferencesProvider.notifier).setIntroOnUpdates,
          ),
          // Deleted: it can be put back at the top of Notes (N16).
          if (ref.watch(introductionAvailableProvider) &&
              preferences.introDeleted)
            ListTile(
              key: const Key('restoreIntro'),
              leading: const Icon(Icons.restore),
              title: const Text('Restore the introduction'),
              subtitle: Text(
                'Puts it back at the top of Notes.',
                style: TextStyle(color: context.colors.textSecondary),
              ),
              onTap: () {
                ref.read(preferencesProvider.notifier).setIntroDeleted(false);
                ScaffoldMessenger.of(context)
                  ..hideCurrentSnackBar()
                  ..showSnackBar(
                    const SnackBar(
                      content: Text('Introduction restored to Notes'),
                    ),
                  );
              },
            ),
          SwitchListTile(
            key: const Key('todoNote'),
            secondary: const Icon(Icons.checklist),
            title: const Text('To-do note'),
            subtitle: Text(
              'A plain to-do list at the top of Notes. Turned off, its list '
              'and options are kept for when it comes back.',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            value: preferences.todoNote,
            onChanged: ref.read(preferencesProvider.notifier).setTodoNote,
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
