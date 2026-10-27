import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  /// In the list, to find it (Round 92: scrolled at its edges while a
  /// section's dragged).
  final _listKey = GlobalKey();

  @override
  void dispose() {
    _edgeScroll?.cancel();
    super.dispose();
  }

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
      check: (name) => _already(name),
      onSubmit: _notifier.add,
    );
  }

  /// Round 92: said when [name] is there already (no two of the same).
  String? _already(String name, {String? except}) =>
      switch (_notifier.named(name, except: except)) {
        null => null,
        (final i, final s) => '${i.name} is already in ${s.name}',
      };

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
          check: (name) => _already(name, except: item.id),
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

  /// A section's name; in edit mode, a tap gives its options, and
  /// (Round 45, all but the first, which stays on top) touching it and
  /// moving drags it: no handle shown.
  Widget _header(IngredientSection section, {Key? key, int? index}) {
    final colors = context.colors;
    Widget header = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
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
        ),
      ),
    );
    if (_picking) return KeyedSubtree(key: key, child: header);
    final tap = GestureDetector(
      behavior: HitTestBehavior.opaque,
      excludeFromSemantics: true,
      onTap: () => _sectionMenu(section),
      child: header,
    );
    // Round 92: dragged only from the right, where an
    // ingredient's handle is (no handle drawn, Round 45); a tap anywhere
    // gives its options. The first stays on top.
    final row = IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: tap),
          if (index != null)
            Draggable<String>(
              key: Key('sectionHandle-${section.id}'),
              data: section.id,
              axis: Axis.vertical,
              // Nothing drawn, still taken hold of.
              hitTestBehavior: HitTestBehavior.opaque,
              // The card held across the row, as its name sits, not
              // hanging off the right edge from the handle.
              dragAnchorStrategy: (_, __, position) =>
                  Offset(position.dx - 12, kMinInteractiveDimension / 2),
              onDragStarted: () => _sectionDragStarted(section.id),
              onDragUpdate: (details) => _sectionDragMoved(
                  ref.read(ingredientsProvider), details.globalPosition.dy),
              onDragEnd: (_) => _sectionDropped(ref.read(ingredientsProvider)),
              feedback: _sectionFeedback(section),
              childWhenDragging:
                  const SizedBox(width: ReorderOrSelectIndicator.width),
              child: const SizedBox(width: ReorderOrSelectIndicator.width),
            )
          else
            const SizedBox(width: ReorderOrSelectIndicator.width),
        ],
      ),
    );
    return Semantics(
      key: key,
      button: true,
      onTap: () => _sectionMenu(section),
      child: Opacity(
        opacity: _draggingSection == section.id ? 0.3 : 1,
        child: row,
      ),
    );
  }

  /// The section being dragged (Round 92), and before which section it
  /// would go (an index in the book's sections; their count: the end).
  String? _draggingSection;
  int? _dropBefore;

  /// The finger, while a section is dragged, for scrolling at the edges.
  double? _dragY;
  Timer? _edgeScroll;

  void _sectionDragStarted(String id) {
    HapticFeedback.selectionClick();
    setState(() => _draggingSection = id);
    _edgeScroll = Timer.periodic(const Duration(milliseconds: 16), (_) {
      final y = _dragY;
      final inList = _listKey.currentContext;
      if (y == null || inList == null) return;
      final scrollable = Scrollable.of(inList);
      final box = scrollable.context.findRenderObject() as RenderBox;
      final top = box.localToGlobal(Offset.zero).dy;
      final position = scrollable.position;
      const edge = 64.0;
      final by = y < top + edge
          ? -8.0
          : y > top + box.size.height - edge
              ? 8.0
              : 0.0;
      if (by != 0) {
        position.jumpTo((position.pixels + by)
            .clamp(position.minScrollExtent, position.maxScrollExtent));
      }
    });
  }

  void _sectionDragEnded() {
    _edgeScroll?.cancel();
    _edgeScroll = null;
    _dragY = null;
    if (mounted) {
      setState(() {
        _draggingSection = null;
        _dropBefore = null;
      });
    }
  }

  /// Where the dragged section would go hovering a row of [sectionIndex]
  /// (its name: before it; one of its ingredients: after it); null where
  /// it wouldn't move. Never above the first.
  int? _dropAt(IngredientBook book, int sectionIndex, {required bool name}) {
    final moving = book.sections.indexWhere((s) => s.id == _draggingSection);
    if (moving < 0) return null;
    final before = (name ? sectionIndex : sectionIndex + 1).clamp(1, 1 << 30);
    return before == moving || before == moving + 1 ? null : before;
  }

  /// The rows shown (Round 92), for where a dragged section would go:
  /// each row's context and its (section's index, whether it's the name).
  final _rowsShown = <BuildContext, (int, bool)>{};

  /// A row a section can be dropped on (Round 92): known by where it is,
  /// so the finger's height alone finds it (the buttons in the corner
  /// don't get in the way).
  Widget _sectionDropTarget(IngredientBook book, int sectionIndex,
      {required bool name, required Widget child}) {
    if (_picking) return child;
    return Builder(builder: (context) {
      _rowsShown[context] = (sectionIndex, name);
      return child;
    });
  }

  /// The finger at [y] while a section's dragged: the row under it marks
  /// where the section would go.
  void _sectionDragMoved(IngredientBook book, double y) {
    _dragY = y;
    _rowsShown.removeWhere((context, _) => !context.mounted);
    for (final MapEntry(key: context, value: (sectionIndex, name))
        in _rowsShown.entries) {
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.attached || !box.hasSize) continue;
      final top = box.localToGlobal(Offset.zero).dy;
      if (y < top || y >= top + box.size.height) continue;
      final at = _dropAt(book, sectionIndex, name: name);
      if (at != _dropBefore) setState(() => _dropBefore = at);
      return;
    }
  }

  /// Let go: the section goes where the line is, if anywhere.
  void _sectionDropped(IngredientBook book) {
    final at = _dropBefore;
    final id = _draggingSection;
    if (at != null && id != null) {
      final moving = book.sections.indexWhere((s) => s.id == id);
      // Its place among the others (it's taken out first).
      _notifier.moveSection(id, at > moving ? at - 1 : at);
    }
    _sectionDragEnded();
  }

  /// The line where a dragged section would go: above [sectionIndex]'s
  /// name (or, its count, under the last row).
  Widget _dropLine(int sectionIndex) => AnimatedContainer(
        key: Key('sectionDropLine-$sectionIndex'),
        duration: const Duration(milliseconds: 120),
        height: _draggingSection != null && _dropBefore == sectionIndex ? 3 : 0,
        margin: const EdgeInsets.symmetric(horizontal: 12),
        color: context.colors.accent,
      );

  /// The section under the finger while dragged: its name on a card.
  Widget _sectionFeedback(IngredientSection section) => Material(
        elevation: 6,
        color: context.colors.card,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: MediaQuery.sizeOf(context).width - 24,
          height: kMinInteractiveDimension,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                '${section.name.toUpperCase()}  ·  ${section.items.length}',
                style: TextStyle(
                  color: context.colors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
        ),
      );

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
              final sectionIndex =
                  book.sections.indexWhere((s) => s.id == row.section.id);
              if (item == null) {
                final first = sectionIndex == 0;
                return Material(
                  key: ValueKey('section-${row.section.id}'),
                  type: MaterialType.transparency,
                  child: _sectionDropTarget(
                    book,
                    sectionIndex,
                    name: true,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _dropLine(sectionIndex),
                        _header(row.section, index: first ? null : index),
                      ],
                    ),
                  ),
                );
              }
              return Padding(
                key: ValueKey(item.id),
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: _sectionDropTarget(
                  book,
                  sectionIndex,
                  name: false,
                  child: _editRow(item, index),
                ),
              );
            },
          ),
          // Round 92: a dragged section's place at the very end.
          SliverToBoxAdapter(
            child: KeyedSubtree(
              key: _listKey,
              child: _dropLine(book.sections.length),
            ),
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
                    icon: Icons.playlist_add,
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
