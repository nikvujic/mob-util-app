import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/preferences_provider.dart';

/// Menu → Settings: small switches for how the app feels.
class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final preferences = ref.watch(preferencesProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        children: [
          SwitchListTile(
            secondary: const Icon(Icons.vibration),
            title: const Text('Counter click and vibration'),
            subtitle: Text(
              'On − and +. The click follows the phone\'s touch sounds '
              'setting.',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            value: preferences.counterFeedback,
            onChanged:
                ref.read(preferencesProvider.notifier).setCounterFeedback,
          ),
        ],
      ),
    );
  }
}
