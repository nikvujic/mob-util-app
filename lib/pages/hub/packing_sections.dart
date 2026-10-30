import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/packing.dart';
import 'package:the_app/pages/hub/page_gate.dart';
import 'package:the_app/widgets/choices_sheet.dart';
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

/// Why [name] can't be a default section's (one of that name is there),
/// or null.
String? sectionTaken(PackingBook book, String name, {String? except}) =>
    book.sectionNamed(name, except: except) == null
        ? null
        : '${name.trim()} is already a section';

/// The default sections (Round 95): what a new packing list starts
/// with; each list then has its own, changed in its edit mode. In order,
/// the handle moves them; a tap renames or deletes one. At least one
/// stays. Changing them doesn't touch the lists there are.
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
        final before = notifier.removeSection(section.id);
        if (before == null) {
          _toast(context, 'At least one section stays');
        } else {
          _toast(context, '${section.name} deleted',
              undo: () => notifier.restoreSections(before));
        }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sections = ref.watch(packingProvider.select((b) => b.sections));
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Default sections')),
      body: PullDownList(
        bottomSpace: BottomActions.contentClearance,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Text(
                'A new list starts with these; each list can change its own.',
                style: TextStyle(color: colors.textMuted),
              ),
            ),
          ),
          SliverReorderableList(
            itemCount: sections.length,
            // onReorderItem only exists on newer Flutter than we target.
            // ignore: deprecated_member_use
            onReorder: ref.read(packingProvider.notifier).reorderSections,
            proxyDecorator: (child, _, __) => Material(
              type: MaterialType.transparency,
              elevation: 6,
              child: child,
            ),
            itemBuilder: (context, index) {
              final section = sections[index];
              return Padding(
                key: ValueKey(section.id),
                padding:
                    const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                child: SelectableCard(
                  key: Key('packingSection-${section.id}'),
                  selected: false,
                  onTap: () => _options(context, ref, section),
                  child: ReorderableRow(
                    content: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 14, 0, 14),
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(section.name,
                            style: TextStyle(
                                fontSize: 16, color: colors.textPrimary)),
                      ),
                    ),
                    indicator: ReorderOrSelectIndicator(
                      index: index,
                      selectionMode: false,
                      selected: false,
                    ),
                  ),
                ),
              );
            },
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
