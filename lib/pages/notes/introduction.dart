import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/introduction_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/markdown_text.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';

/// Opens the Introduction (N16), bringing it back to Notes if it was
/// deleted (from the menu).
void openIntroduction(BuildContext context, WidgetRef ref) {
  ref.read(preferencesProvider.notifier).setIntroDeleted(false);
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const IntroductionPage()),
  );
}

/// The Introduction note (N16): how the app works, then what's new in this
/// version. Read only, drawn as Markdown; it can be deleted (the menu
/// brings it back).
class IntroductionPage extends ConsumerStatefulWidget {
  const IntroductionPage({super.key});

  @override
  ConsumerState<IntroductionPage> createState() => _IntroductionPageState();
}

class _IntroductionPageState extends ConsumerState<IntroductionPage> {
  @override
  void initState() {
    super.initState();
    // Opened: no longer new.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(preferencesProvider.notifier).readIntro();
    });
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete the introduction?',
      message: 'It can be brought back from the menu.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    final preferences = ref.read(preferencesProvider.notifier);
    preferences.setIntroDeleted(true);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Introduction deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => preferences.setIntroDeleted(false),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    final text = ref.watch(introductionTextProvider);
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Introduction')),
      body: switch (text) {
        AsyncData(:final value) => PullDownList.children(
            bottomSpace: BottomActions.contentClearance,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                child: Text.rich(
                  key: const Key('introductionText'),
                  // The notes' own Markdown look, read only.
                  MarkdownEditingController(text: value).buildTextSpan(
                    context: context,
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 16,
                      height: 1.4,
                    ),
                    withComposing: false,
                  ),
                ),
              ),
            ],
          ),
        AsyncError() => Center(
            child: Text(
              "The introduction couldn't be read.",
              style: TextStyle(color: colors.textSecondary),
            ),
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
      floatingActionButton: BottomActions(
        actions: [
          BottomAction(
            icon: Icons.delete_outline,
            tooltip: 'Delete introduction',
            danger: true,
            onPressed: _delete,
          ),
        ],
      ),
    );
  }
}

/// The Introduction at the top of the Notes list (N16): a note of its own
/// kind, not selectable or movable; "New" after an install or update.
class IntroductionTile extends ConsumerWidget {
  /// Selection mode is on in the list: it takes no part (taps do nothing).
  final bool selectionMode;

  const IntroductionTile({super.key, required this.selectionMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(preferencesProvider.select((p) => p.introUnread));
    final colors = context.colors;
    return SelectableCard(
      key: const Key('introductionTile'),
      selected: false,
      onTap: selectionMode ? null : () => openIntroduction(context, ref),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Icon(Icons.auto_stories_outlined, color: colors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Introduction',
                    style: TextStyle(color: colors.textPrimary, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    "How the app works, and what's new",
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (unread)
              Container(
                key: const Key('introductionNew'),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: colors.accent,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'New',
                  style: TextStyle(
                    color: colors.onAccent,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
