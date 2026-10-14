import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/pages/hub/page_gate.dart';
import 'package:the_app/providers/recipes_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';
import 'package:the_app/widgets/text_input_sheet.dart';

/// Opens the ingredients list to manage it (Round 42).
void openIngredients(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => const PageGate(
        page: HubTool.recipes,
        child: IngredientsPage(),
      ),
    ),
  );
}

/// Opens the ingredients list to pick from (a recipe's + Add), [already]
/// in the recipe ticked and greyed. The ingredients picked, in the list's
/// order; null if left without adding.
Future<List<Ingredient>?> pickIngredients(
  BuildContext context, {
  required Set<String> already,
}) =>
    Navigator.of(context).push(
      MaterialPageRoute<List<Ingredient>>(
        builder: (_) => PageGate(
          page: HubTool.recipes,
          child: IngredientsPage(picking: true, already: already),
        ),
      ),
    );

/// The ingredients list (Round 42), in sections: one list for all
/// recipes. **Edit mode** (from Recipes): + adds ingredients (to the top
/// of the first section), Section adds a section (under the first, which
/// stays on top: Round 43; the others move by their handle), the handle
/// drags an ingredient (between sections too), holding one or a
/// section's name renames or deletes it. **Pick mode** (from a recipe):
/// boxes to tick and a wide Add button; Edit switches to edit mode, and
/// back returns to picking.
class IngredientsPage extends ConsumerStatefulWidget {
  /// Opened to pick from (else to manage).
  final bool picking;

  /// In the recipe already (pick mode): ticked, greyed.
  final Set<String> already;

  const IngredientsPage({
    super.key,
    this.picking = false,
    this.already = const {},
  });

  @override
  ConsumerState<IngredientsPage> createState() => _IngredientsPageState();
}

/// One row of the list: a section's name, or an ingredient in it.
typedef _Row = ({IngredientSection section, Ingredient? item});

class _IngredientsPageState extends ConsumerState<IngredientsPage> {
  late bool _picking = widget.picking;
  final _picked = <String>{};

  IngredientsNotifier get _notifier => ref.read(ingredientsProvider.notifier);

  /// The list flat, as shown: each section's name, then its ingredients.
  static List<_Row> _rows(IngredientBook book) => [
        for (final section in book.sections) ...[
          (section: section, item: null),
          for (final item in section.items) (section: section, item: item),
        ],
      ];

  void _toast(String message, {VoidCallback? undo}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        action: undo == null
            ? null
            : SnackBarAction(label: 'Undo', onPressed: undo),
      ));
  }

  void _add() {
    showTextInputSheet(
      context,
      hint: 'Add an ingredient',
      submitLabel: 'Add',
      keepOpen: true,
      onSubmit: _notifier.add,
    );
  }

  void _addSection() {
    showTextInputSheet(
      context,
      // Under the first section (Round 43).
      hint: 'Section, e.g. Dairy',
      submitLabel: 'Add',
      onSubmit: _notifier.addSection,
    );
  }

  /// A row dropped at [newIndex] (`onReorder` semantics): into the
  /// section above where it lands. Sections themselves don't move.
  void _reorder(List<_Row> rows, int oldIndex, int newIndex) {
    final moving = rows[oldIndex].item;
    if (moving == null) {
      _moveSection(rows, oldIndex, newIndex);
      return;
    }
    if (newIndex > oldIndex) newIndex--;
    final rest = [...rows]..removeAt(oldIndex);
    // Above the first section's name: the top of the first section.
    if (newIndex == 0) {
      _notifier.move(moving.id, sectionId: rest.first.section.id, index: 0);
      return;
    }
    final above = rest[newIndex - 1];
    final index = above.item == null
        ? 0
        : above.section.items.where((i) => i.id != moving.id).toList().indexOf(
                  above.item!,
                ) +
            1;
    _notifier.move(moving.id, sectionId: above.section.id, index: index);
  }

  /// A section's name dropped at [newIndex] (Round 43): the section goes
  /// after the sections whose names are above that place (never above the
  /// first one).
  void _moveSection(List<_Row> rows, int oldIndex, int newIndex) {
    final section = rows[oldIndex].section;
    final before = rows
        .take(newIndex)
        .where((r) => r.item == null && r.section.id != section.id)
        .length;
    _notifier.moveSection(section.id, before);
  }

  Future<void> _sectionMenu(IngredientSection section) async {
    final choice = await _menu(section.name, [
      (Icons.edit_outlined, 'Rename', 'rename'),
      (Icons.delete_outline, 'Delete section', 'delete'),
    ]);
    if (!mounted) return;
    switch (choice) {
      case 'rename':
        await showTextInputSheet(
          context,
          hint: 'Section',
          initialValue: section.name,
          onSubmit: (name) => _notifier.renameSection(section.id, name),
        );
      case 'delete':
        final before = _notifier.deleteSection(section.id);
        if (before == null) {
          _toast('The first section stays');
        } else {
          _toast(
            section.items.isEmpty
                ? '${section.name} deleted'
                : '${section.name} deleted; its ingredients moved up',
            undo: () => _notifier.replaceAll(before),
          );
        }
    }
  }

  Future<void> _itemMenu(Ingredient item) async {
    final choice = await _menu(item.name, [
      (Icons.edit_outlined, 'Rename', 'rename'),
      (Icons.delete_outline, 'Delete', 'delete'),
    ]);
    if (!mounted) return;
    switch (choice) {
      case 'rename':
        await showTextInputSheet(
          context,
          hint: 'Ingredient',
          initialValue: item.name,
          onSubmit: (name) => _notifier.rename(item.id, name),
        );
      case 'delete':
        final before = _notifier.delete(item.id);
        _toast('${item.name} deleted',
            undo: () => _notifier.replaceAll(before));
    }
  }

  /// A small sheet of choices, at the bottom (one-handed).
  Future<String?> _menu(
    String title,
    List<(IconData, String, String)> choices,
  ) =>
      showModalBottomSheet<String>(
        context: context,
        builder: (context) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              ),
              for (final (icon, label, value) in choices)
                ListTile(
                  leading: Icon(icon),
                  title: Text(label),
                  onTap: () => Navigator.of(context).pop(value),
                ),
            ],
          ),
        ),
      );

  void _togglePick(String id) => setState(() {
        if (!_picked.remove(id)) _picked.add(id);
      });

  void _accept() {
    final book = ref.read(ingredientsProvider);
    Navigator.of(context).pop([
      for (final i in book.all)
        if (_picked.contains(i.id)) i,
    ]);
  }

  /// A section's name; in edit mode, held for its options, and (all but
  /// the first, which stays on top: Round 43) with a handle to move it.
  Widget _header(IngredientSection section, {Key? key, int? index}) {
    final colors = context.colors;
    final title = Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
      child: Text(
        '${section.name.toUpperCase()}  ·  ${section.items.length}',
        key: Key('ingredientSection-${section.id}'),
        style: TextStyle(
          color: colors.accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
    return GestureDetector(
      key: key,
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onLongPress: _picking ? null : () => _sectionMenu(section),
      child: index == null
          ? title
          : ReorderableRow(
              content: Align(alignment: Alignment.bottomLeft, child: title),
              indicator: ReorderOrSelectIndicator(
                index: index,
                selectionMode: false,
                selected: false,
              ),
            ),
    );
  }

  Widget _editRow(Ingredient item, int index) {
    return SelectableCard(
      key: Key('ingredient-${item.id}'),
      selected: false,
      onLongPress: () => _itemMenu(item),
      child: ReorderableRow(
        content: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
          child: Text(
            item.name,
            style: TextStyle(fontSize: 15, color: context.colors.textPrimary),
          ),
        ),
        indicator: ReorderOrSelectIndicator(
          index: index,
          selectionMode: false,
          selected: false,
        ),
      ),
    );
  }

  Widget _pickRow(Ingredient item) {
    final colors = context.colors;
    final already = widget.already.contains(item.id);
    final ticked = already || _picked.contains(item.id);
    return SelectableCard(
      key: Key('ingredient-${item.id}'),
      selected: false,
      onTap: already ? null : () => _togglePick(item.id),
      child: Semantics(
        checked: ticked,
        enabled: !already,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              SizedBox.square(
                dimension: kMinInteractiveDimension,
                child: Icon(
                  ticked ? Icons.check_box : Icons.check_box_outline_blank,
                  color: already
                      ? colors.textMuted
                      : ticked
                          ? colors.accent
                          : colors.textSecondary,
                ),
              ),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 15,
                    color: already ? colors.textMuted : colors.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(ingredientsProvider);
    final rows = _rows(book);
    // Gone from the list meanwhile (deleted in edit mode): not picked.
    _picked.retainWhere((id) => book.byId(id) != null);

    final Widget body;
    if (book.size == 0 && book.sections.isEmpty) {
      body = EmptyState(
        icon: Icons.kitchen_outlined,
        message: _picking
            ? 'No ingredients yet: Edit to add some'
            : 'No '
                'ingredients',
      );
    } else if (_picking) {
      body = PullDownList(
        bottomSpace: BottomActions.contentClearance + 72,
        slivers: [
          SliverList.list(children: [
            for (final row in rows)
              if (row.item case final item?)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: _pickRow(item),
                )
              else
                _header(row.section),
          ]),
        ],
      );
    } else {
      body = PullDownList(
        bottomSpace: BottomActions.contentClearance,
        slivers: [
          SliverReorderableList(
            itemCount: rows.length,
            // onReorderItem only exists on newer Flutter than we target.
            // ignore: deprecated_member_use
            onReorder: (from, to) => _reorder(rows, from, to),
            proxyDecorator: (child, _, __) => Material(
              type: MaterialType.transparency,
              elevation: 6,
              child: child,
            ),
            itemBuilder: (context, index) {
              final row = rows[index];
              final item = row.item;
              if (item == null) {
                final first = row.section.id == book.sections.first.id;
                return Material(
                  key: ValueKey('section-${row.section.id}'),
                  type: MaterialType.transparency,
                  child: _header(row.section, index: first ? null : index),
                );
              }
              return Padding(
                key: ValueKey(item.id),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _editRow(item, index),
              );
            },
          ),
        ],
      );
    }

    return PopScope(
      // Opened to pick: back from edit mode returns to picking.
      canPop: !(widget.picking && !_picking),
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) setState(() => _picking = true);
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_picking ? 'Pick ingredients' : 'Ingredients'),
        ),
        body: body,
        floatingActionButton: _picking
            ? BottomActions(
                actions: [
                  BottomAction(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit ingredients',
                    onPressed: () => setState(() => _picking = false),
                  ),
                ],
              )
            : BottomActions(
                actions: [
                  BottomAction(
                    icon: Icons.create_new_folder_outlined,
                    tooltip: 'Add a section',
                    onPressed: _addSection,
                  ),
                  BottomAction(
                    icon: Icons.add,
                    tooltip: 'Add ingredients',
                    primary: true,
                    onPressed: _add,
                  ),
                ],
              ),
        bottomNavigationBar: _picking
            ? SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    key: const Key('addPicked'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(52),
                    ),
                    onPressed: _picked.isEmpty ? null : _accept,
                    child: Text(
                      _picked.isEmpty ? 'Add' : 'Add ${_picked.length}',
                    ),
                  ),
                ),
              )
            : null,
      ),
    );
  }
}
