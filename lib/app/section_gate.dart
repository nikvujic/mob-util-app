import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/widgets/main_app_bar.dart';
import 'package:the_app/widgets/password_prompt.dart';

/// Shows [child] (a main section), or a lock screen while the section is
/// closed (L5): locked, with the app locked. The section's page isn't
/// built at all meanwhile, so nothing of it is on screen.
class SectionGate extends ConsumerWidget {
  final AppSection section;
  final Widget child;

  const SectionGate({super.key, required this.section, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!ref.watch(sectionClosedProvider(section))) return child;
    return Scaffold(
      appBar: MainAppBar(title: section.label),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.lock_outline,
                size: 48,
                color: context.colors.textSecondary,
              ),
              const SizedBox(height: 16),
              Text(
                '${section.label} is locked',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 18,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Enter the master password to open it.',
                textAlign: TextAlign.center,
                style: TextStyle(color: context.colors.textSecondary),
              ),
              const SizedBox(height: 24),
              FilledButton.icon(
                icon: const Icon(Icons.lock_open_outlined),
                label: const Text('Unlock'),
                onPressed: () => showPasswordPrompt<UnlockedKeys>(
                  context,
                  title: 'Unlock',
                  confirmLabel: 'Unlock',
                  attempt: ref.read(sessionProvider.notifier).unlock,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
