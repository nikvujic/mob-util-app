import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// Menu → Themes (G12): pick the app's look; it applies at once.
class ThemesPage extends ConsumerWidget {
  const ThemesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final current = AppThemeChoice.fromId(
      ref.watch(preferencesProvider.select((p) => p.theme)),
    );
    return Scaffold(
      appBar: AppBar(title: const Text('Themes')),
      body: PullDownList.children(
        children: [
          for (final theme in AppThemeChoice.values)
            ListTile(
              leading: _Swatch(palette: theme.palette),
              title: Text(theme.label),
              trailing: theme == current
                  ? Icon(Icons.check, color: context.colors.accent)
                  : null,
              selected: theme == current,
              onTap: () =>
                  ref.read(preferencesProvider.notifier).setTheme(theme.name),
            ),
        ],
      ),
    );
  }
}

/// A small preview of a palette: its background, a card and the accent.
class _Swatch extends StatelessWidget {
  final AppPalette palette;

  const _Swatch({required this.palette});

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Container(
        width: 48,
        height: 36,
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: palette.background,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: context.colors.divider),
        ),
        child: Row(
          children: [
            Expanded(
              child: Container(
                decoration: BoxDecoration(
                  color: palette.card,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(width: 4),
            Container(
              width: 12,
              decoration: BoxDecoration(
                color: palette.accent,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
