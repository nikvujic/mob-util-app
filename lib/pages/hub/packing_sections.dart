import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/packing.dart';
import 'package:the_app/pages/hub/page_gate.dart';
import 'package:the_app/pages/hub/recipe_page.dart' show showChoicesSheet;
import 'package:the_app/providers/packing_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';
import 'package:the_app/widgets/text_input_sheet.dart';

void openPackingSections(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const PageGate(
        page: HubTool.packing,
        child: PackingSectionsPage(),
      ),
    ),
  );
}

/// Why [name] can't be a section's (one of that name is there), or null.
String? sectionTaken(PackingBook book, String name, {String? except}) =>
    book.sectionNamed(name, except: except) == null
        ? null
        : '${name.trim()} is already a section';

/// The sections every packing list shares (Round 94): in order, the
/// handle moves them; a tap renames or deletes one (its items, in every
/// list, go to Other). Other is always there, last, as it is.
class PackingSectionsPage extends ConsumerWidget {
  const PackingSectionsPage({super.key});

  void _toast(BuildContext context, String message, {VoidCallback? undo}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        action: undo == null
            ? null
            : SnackBarAction(label: 'Undo', onPressed: undo),
      ));
  }

  Future<void> _add(BuildContext context, WidgetRef ref) => showTextInputSheet(
        context,
        hint: 'Section, e.g. Ski gear',
        submitLabel: 'Add',
        keepOpen: true,
        check: (name) => sectionTaken(ref.read(packingProvider), name),
        onSubmit: ref.read(packingProvider.notifier).addSection,
      );

  Future<void> _options(
    BuildContext context,
    WidgetRef ref,
    PackingSection section,
  ) async {
    final notifier = ref.read(packingProvider.notifier);
    final choice = await showChoicesSheet(context, section.name, const [
      (Icons.edit_outlined, 'Rename', 'rename'),
      (Icons.delete_outline, 'Delete', 'delete'),
    ]);
    if (!context.mounted) return;
    switch (choice) {
      case 'rename':
        await showTextInputSheet(
          context,
          hint: 'Section',
          initialValue: section.name,
          check: (name) =>
              sectionTaken(ref.read(packingProvider), name, except: section.id),
          onSubmit: (name) => notifier.renameSection(section.id, name),
        );
      case 'delete':
        final items = ref.read(packingProvider).itemsIn(section.id);
        final before = notifier.removeSection(section.id);
        _toast(
          context,
          items == 0
              ? '${section.name} deleted'
              : '${section.name} deleted; its items moved to Other',
          undo: () => notifier.replaceAll(before),
        );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(packingProvider);
    final movable = [
      for (final s in book.sections)
        if (!s.isOther) s,
    ];
    final colors = context.colors;

    Widget row(PackingSection section, {int? index}) {
      final items = book.itemsIn(section.id);
      final content = Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(section.name,
                style: TextStyle(fontSize: 16, color: colors.textPrimary)),
            if (section.isOther)
              Text(
                'Always there, last',
                style: TextStyle(fontSize: 13, color: colors.textMuted),
              )
            else if (items > 0)
              Text(
                items == 1 ? '1 item' : '$items items',
                style: TextStyle(fontSize: 13, color: colors.textSecondary),
              ),
          ],
        ),
      );
      return SelectableCard(
        key: Key('packingSection-${section.id}'),
        selected: false,
        onTap: section.isOther ? null : () => _options(context, ref, section),
        child: ReorderableRow(
          content: content,
          indicator: ReorderOrSelectIndicator(
            index: index ?? 0,
            reorderable: index != null,
            selectionMode: false,
            selected: false,
          ),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Sections')),
      body: PullDownList(
        bottomSpace: BottomActions.contentClearance,
        slivers: [
          SliverPadding(
            padding: const EdgeInsets.only(top: 4),
            sliver: SliverReorderableList(
              itemCount: movable.length,
              // onReorderItem only exists on newer Flutter than we target.
              // ignore: deprecated_member_use
              onReorder: ref.read(packingProvider.notifier).reorderSections,
              proxyDecorator: (child, _, __) => Material(
                type: MaterialType.transparency,
                elevation: 6,
                child: child,
              ),
              itemBuilder: (context, index) => Padding(
                key: ValueKey(movable[index].id),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                child: row(movable[index], index: index),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
            sliver: SliverToBoxAdapter(child: row(book.sections.last)),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Text(
                'Every packing list uses these sections.',
                style: TextStyle(color: colors.textMuted),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: BottomActions(
        actions: [
          BottomAction(
            icon: Icons.add,
            tooltip: 'New section',
            primary: true,
            onPressed: () => _add(context, ref),
          ),
        ],
      ),
    );
  }
}
