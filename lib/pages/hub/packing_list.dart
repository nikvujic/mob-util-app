import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/packing.dart';
import 'package:the_app/pages/hub/packing.dart';
import 'package:the_app/pages/hub/packing_copy_sheet.dart';
import 'package:the_app/pages/hub/recipe_page.dart' show showChoicesSheet;
import 'package:the_app/providers/packing_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/low_handles.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';
import 'package:the_app/widgets/text_input_sheet.dart';

/// One packing list (Round 94; Round 95: Nikola's changes). It opens in
/// **view mode**: its sections, each thing a row with a box; a tap
/// anywhere on a row ticks it (or unticks it), in place. **Reset**
/// unticks them all, asked first. **Edit**: its name, its own sections
/// (a heading's tap renames, moves or deletes one, things and all, asked
/// first; **Add section** at the end; at least one stays), **+ Add** under
/// each section, a thing's tap renames it or sets its count, holding
/// things selects them to delete, the handle drags one, into another
/// section too. Saved as it's changed; Back asks Save or Discard (Discard
/// puts it back as it was). A new list ([draft]) opens as **New list**;
/// Done takes it to the lists page, not to its view.
class PackingListPage extends ConsumerStatefulWidget {
  /// The list (kept); null with [draft].
  final String? listId;

  /// A new list, kept once something's put in it.
  final PackingList? draft;

  const PackingListPage({super.key, required String this.listId})
      : draft = null;

  const PackingListPage.create({super.key, required PackingList this.draft})
      : listId = null;

  @override
  ConsumerState<PackingListPage> createState() => _PackingListPageState();
}

class _PackingListPageState extends ConsumerState<PackingListPage> {
  static const _saveDelay = Duration(milliseconds: 600);

  bool get _isNew => widget.draft != null;
  String get _id => widget.listId ?? widget.draft!.id;

  late bool _editing = _isNew;

  /// The list as being edited (edit mode only; view mode shows what's
  /// stored).
  late PackingList _list;

  /// As it was when Edit was pressed (a new one: empty): Discard goes back
  /// to it.
  late PackingList _original;

  /// Things held to select, to delete together.
  final _selected = <String>{};

  late final TextEditingController _name;
  final _nameFocus = FocusNode();

  /// Set while Discard puts the name back in its field.
  bool _applying = false;

  /// Set once it's gone (deleted, discarded): nothing more saved.
  bool _gone = false;

  /// A new one put in the book (once something's in it).
  bool _kept = false;

  bool _asking = false;

  Timer? _saveTimer;

  /// Kept from the start: saving on closing comes after `ref` is gone.
  late final PackingNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(packingProvider.notifier);
    _list = widget.draft ?? _notifier.byId(_id)!;
    _original = _list;
    _name = TextEditingController(text: _list.name)..addListener(_onName);
  }

  @override
  void dispose() {
    _saveNow();
    _name.dispose();
    _nameFocus.dispose();
    super.dispose();
  }

  void _onName() {
    if (_applying || _name.text == _list.name) return;
    setState(() => _list = _list.copyWith(name: _name.text));
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _saveNow);
  }

  /// A change other than typing, saved at once.
  void _change(PackingList next) {
    setState(() => _list = next);
    _saveNow();
  }

  void _saveNow() {
    _saveTimer?.cancel();
    if (_gone || !_editing) return;
    // A new one is kept once something's in it.
    if (_isNew && !_kept && _list.isEmpty) return;
    _notifier.save(_list);
    _kept = true;
  }

  bool get _changed => !_list.sameAs(_original);

  void _edit() => setState(() {
        _list = _notifier.byId(_id) ?? _list;
        _original = _list;
        _applying = true;
        _name.text = _list.name;
        _applying = false;
        _selected.clear();
        _editing = true;
      });

  /// Done: saved; a new one goes to the lists page (Nikola: not to its
  /// view), dropped if nothing's in it; one being edited back to view.
  void _done() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_isNew) {
      if (_list.isEmpty) {
        _drop();
      } else {
        _saveNow();
        _gone = true;
      }
      Navigator.of(context).pop();
      return;
    }
    _saveNow();
    setState(() {
      _selected.clear();
      _editing = false;
    });
  }

  /// A new one taken back out of the book.
  void _drop() {
    _gone = true;
    _saveTimer?.cancel();
    if (_kept) _notifier.remove({_id});
  }

  void _discard() {
    if (_isNew) {
      _drop();
      Navigator.of(context).pop();
      return;
    }
    _saveTimer?.cancel();
    _notifier.save(_original);
    _applying = true;
    _name.text = _original.name;
    _applying = false;
    setState(() {
      _list = _original;
      _selected.clear();
      _editing = false;
    });
  }

  /// Back in edit mode: the selection, then the name's keyboard, then
  /// Save or Discard if anything changed (Nikola, as a note).
  Future<void> _onBack() async {
    if (_selected.isNotEmpty) {
      setState(_selected.clear);
      return;
    }
    if (_nameFocus.hasFocus) {
      _leaveFields();
      return;
    }
    if (!_changed) {
      _isNew ? _discard() : _done();
      return;
    }
    if (_asking) return;
    _asking = true;
    final save = await showSaveChangesDialog(
      context,
      title: _isNew ? 'Save new list?' : 'Save changes?',
      message: _isNew
          ? 'New lists are saved automatically. Discard deletes this list.'
          : 'Your changes are saved automatically. Discard puts the list '
              'back the way it was.',
    );
    _asking = false;
    if (!mounted || save == null) return; // tapped outside: stay
    save ? _done() : _discard();
  }

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

  // View mode's actions.

  void _tick(PackingItem item) {
    HapticFeedback.selectionClick();
    _notifier.toggle(_id, item.id);
  }

  /// Asked first (Nikola), no Undo after.
  Future<void> _reset() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Reset the list?',
      message: 'Everything ticked is unticked.',
      confirmLabel: 'Reset',
    );
    if (!confirmed || !mounted) return;
    _notifier.reset(_id);
  }

  /// The copy goes on the lists page, under this one; back there.
  Future<void> _copy(PackingList list) async {
    final picked = await showCopyListSheet(
      context,
      list: list,
      groups: list.grouped(),
    );
    if (picked == null || !mounted) return;
    if (_notifier.copy(list.id, picked.name, picked.sectionIds) == null) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text('${picked.name} made')));
  }

  void _delete(PackingList list) {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = _notifier;
    final name = list.name.trim().isEmpty ? 'Untitled' : list.name;
    _gone = true;
    _saveTimer?.cancel();
    final removed = notifier.remove({_id});
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$name deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.undoRemove(removed),
        ),
      ));
  }

  Future<void> _more(PackingList list) async {
    final choice = await showChoicesSheet(context, null, const [
      (Icons.copy_all_outlined, 'Copy list', 'copy'),
      (Icons.delete_outline, 'Delete', 'delete'),
    ]);
    if (!mounted) return;
    switch (choice) {
      case 'copy':
        await _copy(list);
      case 'delete':
        _delete(list);
    }
  }

  // Edit mode's changes.

  void _leaveFields() => FocusManager.instance.primaryFocus?.unfocus();

  /// Why [name] can't go into [section] (it's there), or null.
  String? _already(String name, PackingSection section, {String? except}) =>
      _list.named(name, section.id, except: except) == null
          ? null
          : '${name.trim()} is already in ${section.name}';

  String? _sectionTaken(String name, {String? except}) =>
      _list.sectionNamed(name, except: except) == null
          ? null
          : '${name.trim()} is already a section';

  Future<void> _addTo(PackingSection section) async {
    _leaveFields();
    await showTextInputSheet(
      context,
      hint: 'Add to ${section.name}',
      submitLabel: 'Add',
      keepOpen: true,
      check: (name) => _already(name, section),
      onSubmit: (name) {
        if (!mounted || !_editing) return;
        _change(_list.copyWith(items: [
          ..._list.items,
          PackingItem(id: generateId(), name: name, sectionId: section.id),
        ]));
      },
    );
  }

  Future<void> _addSection() async {
    _leaveFields();
    final name = await showTextInputSheet(
      context,
      hint: 'Section, e.g. Ski gear',
      submitLabel: 'Add',
      check: _sectionTaken,
    );
    if (name == null || !mounted || !_editing) return;
    _change(_list.copyWith(sections: [
      ..._list.sections,
      PackingSection(id: generateId(), name: name.trim()),
    ]));
  }

  Future<void> _sectionOptions(PackingSection section) async {
    _leaveFields();
    final at = _list.sections.indexOf(section);
    final choice = await showChoicesSheet(context, section.name, [
      (Icons.edit_outlined, 'Rename', 'rename'),
      if (at > 0) (Icons.arrow_upward, 'Move up', 'up'),
      if (at < _list.sections.length - 1)
        (Icons.arrow_downward, 'Move down', 'down'),
      (Icons.delete_outline, 'Delete', 'delete'),
    ]);
    if (!mounted || !_editing) return;
    switch (choice) {
      case 'rename':
        final name = await showTextInputSheet(
          context,
          hint: 'Section',
          initialValue: section.name,
          check: (name) => _sectionTaken(name, except: section.id),
        );
        if (name == null || !mounted || !_editing) return;
        _change(_list.copyWith(sections: [
          for (final s in _list.sections)
            if (s.id == section.id) s.copyWith(name: name.trim()) else s,
        ]));
      case 'up':
        _change(_list.sectionMoved(section.id, -1));
      case 'down':
        _change(_list.sectionMoved(section.id, 1));
      case 'delete':
        await _deleteSection(section);
    }
  }

  /// With its things, asked first if it has any (Nikola); the last one
  /// stays.
  Future<void> _deleteSection(PackingSection section) async {
    if (_list.sections.length <= 1) {
      _toast('A list needs at least one section');
      return;
    }
    final things = _list.grouped().firstWhere((g) => g.$1 == section).$2;
    if (things.isNotEmpty) {
      final confirmed = await showConfirmDialog(
        context,
        title: 'Delete ${section.name}?',
        message: things.length == 1
            ? 'Its 1 thing goes with it.'
            : 'Its ${things.length} things go with it.',
        confirmLabel: 'Delete',
        destructive: true,
      );
      if (!confirmed || !mounted || !_editing) return;
    }
    _change(_list.withoutSection(section.id));
  }

  PackingSection _sectionOf(PackingItem item) =>
      _list.section(item.sectionId) ?? _list.sections.last;

  Future<void> _itemOptions(PackingItem item) async {
    _leaveFields();
    final choice = await showChoicesSheet(context, item.name, const [
      (Icons.edit_outlined, 'Rename', 'rename'),
      (Icons.numbers, 'Count', 'count'),
    ]);
    if (!mounted || !_editing) return;
    void replace(PackingItem next) => _change(_list.copyWith(items: [
          for (final i in _list.items)
            if (i.id == item.id) next else i,
        ]));
    switch (choice) {
      case 'rename':
        final name = await showTextInputSheet(
          context,
          hint: 'Thing',
          initialValue: item.name,
          check: (name) => _already(name, _sectionOf(item), except: item.id),
        );
        if (name == null || name == item.name || !mounted || !_editing) {
          return;
        }
        replace(item.copyWith(name: name));
      case 'count':
        final count = await showCountSheet(context, item);
        if (count == null || count == item.count || !mounted || !_editing) {
          return;
        }
        replace(item.copyWith(count: count));
    }
  }

  void _toggleSelected(String id) {
    _leaveFields();
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(id)) _selected.add(id);
    });
  }

  void _deleteSelected() {
    final ids = {..._selected};
    _change(_list.copyWith(items: [
      for (final i in _list.items)
        if (!ids.contains(i.id)) i,
    ]));
    setState(_selected.clear);
  }

  @override
  Widget build(BuildContext context) {
    final stored = ref.watch(packingProvider.select((b) => b.byId(_id)));
    final list = _editing ? _list : (stored ?? _list);
    final name = list.name.trim();
    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _editing
                ? (_isNew ? 'New list' : 'Edit list')
                : (name.isEmpty ? 'Untitled' : name),
          ),
        ),
        body: _editing ? _editBody(context) : _viewBody(context, list),
        floatingActionButton: _editing
            ? BottomActions(
                actions: [
                  if (_selected.isNotEmpty)
                    BottomAction(
                      icon: Icons.delete_outline,
                      tooltip: 'Delete selected',
                      danger: true,
                      onPressed: _deleteSelected,
                    )
                  else
                    BottomAction(
                      icon: Icons.check,
                      tooltip: 'Done',
                      primary: true,
                      onPressed: _done,
                    ),
                ],
              )
            : BottomActions(
                actions: [
                  BottomAction(
                    icon: Icons.more_horiz,
                    tooltip: 'More',
                    onPressed: () => _more(list),
                  ),
                  BottomAction(
                    icon: Icons.restart_alt,
                    tooltip: 'Reset',
                    enabled: list.packedCount > 0,
                    onPressed: _reset,
                  ),
                  BottomAction(
                    icon: Icons.edit_outlined,
                    tooltip: 'Edit',
                    primary: true,
                    onPressed: _edit,
                  ),
                ],
              ),
      ),
    );
  }

  Widget _heading(String text, {Key? key, VoidCallback? onTap}) {
    final label = ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
      child: Align(
        alignment: Alignment.bottomLeft,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 6),
          child: Text(
            text,
            key: key,
            style: TextStyle(
              color: context.colors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        ),
      ),
    );
    if (onTap == null) return label;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: label,
    );
  }

  Widget _viewBody(BuildContext context, PackingList list) {
    final colors = context.colors;
    if (list.items.isEmpty) {
      return const EmptyState(
        icon: Icons.luggage_outlined,
        message: 'Nothing to pack yet: Edit to add things',
      );
    }
    final size = list.items.length;
    final packed = list.packedCount;
    return PullDownList(
      key: const Key('packingView'),
      bottomSpace: BottomActions.contentClearance,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  packedLabel(list),
                  key: const Key('packingProgress'),
                  style: TextStyle(
                    color: packed == size ? colors.accent : colors.textPrimary,
                    fontSize: 15,
                  ),
                ),
                const SizedBox(height: 8),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: packed / size,
                    minHeight: 6,
                    backgroundColor: colors.card,
                  ),
                ),
              ],
            ),
          ),
        ),
        for (final (section, items) in list.grouped()) ...[
          SliverToBoxAdapter(
            child: _heading(
              '${section.name.toUpperCase()}  ·  '
              '${items.where((i) => i.packed).length}/${items.length}',
              key: Key('packingSection-${section.id}'),
            ),
          ),
          SliverList.list(
            children: [
              for (final item in items)
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                  child: _TickRow(item: item, onTap: () => _tick(item)),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _editBody(BuildContext context) {
    final colors = context.colors;
    const clearance = BottomActions.contentClearance;
    // A heading, its things, then its "+ Add" row; the add rows aren't in
    // the model's rows (headings and things), so indexes are mapped.
    final rows = <Object>[
      for (final (section, items) in _list.grouped()) ...[
        section,
        ...items,
        (add: section),
      ],
    ];
    int modelIndex(int index) =>
        index - rows.take(index).whereType<({PackingSection add})>().length;
    return PullDownList(
      key: const Key('packingEdit'),
      bottomSpace: clearance,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              key: const Key('packingName'),
              selectionControls: lowHandles,
              controller: _name,
              focusNode: _nameFocus,
              // No room asked for above it (Round 95, as a recipe's name in
              // Round 64): at the list's top that pulled into the reach
              // space at every key, which snapped back: the page bounced.
              scrollPadding:
                  const EdgeInsets.fromLTRB(20, 0, 20, clearance + 20),
              autofocus: _isNew,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              style: TextStyle(color: colors.textPrimary, fontSize: 20),
              decoration: InputDecoration(
                hintText: 'Name, e.g. Ski trip',
                hintStyle: TextStyle(color: colors.textHint),
              ),
              onSubmitted: (_) => _leaveFields(),
            ),
          ),
        ),
        SliverReorderableList(
          itemCount: rows.length,
          // onReorderItem only exists on newer Flutter than we target.
          // ignore: deprecated_member_use
          onReorder: (from, to) {
            final next = _list.moved(modelIndex(from), modelIndex(to));
            if (!next.sameAs(_list)) _change(next);
          },
          proxyDecorator: (child, _, __) => Material(
            type: MaterialType.transparency,
            elevation: 6,
            child: child,
          ),
          itemBuilder: (context, index) {
            final row = rows[index];
            if (row is PackingSection) {
              final count = _list.grouped().firstWhere((g) => g.$1 == row).$2;
              return KeyedSubtree(
                key: ValueKey('section-${row.id}'),
                child: _heading(
                  '${row.name.toUpperCase()}  ·  ${count.length}',
                  key: Key('packingSection-${row.id}'),
                  onTap: () => _sectionOptions(row),
                ),
              );
            }
            if (row is ({PackingSection add})) {
              return Padding(
                key: ValueKey('add-${row.add.id}'),
                padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    key: Key('packingAdd-${row.add.id}'),
                    icon: const Icon(Icons.add),
                    label: const Text('Add'),
                    onPressed: () => _addTo(row.add),
                  ),
                ),
              );
            }
            final item = row as PackingItem;
            final selected = _selected.contains(item.id);
            return Padding(
              key: ValueKey(item.id),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: SelectableCard(
                key: Key('packingItem-${item.id}'),
                selected: selected,
                onTap: () => _selected.isNotEmpty
                    ? _toggleSelected(item.id)
                    : _itemOptions(item),
                onLongPress: () => _toggleSelected(item.id),
                child: ReorderableRow(
                  content: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            item.name,
                            style: TextStyle(
                              fontSize: 15,
                              color: colors.textPrimary,
                            ),
                          ),
                        ),
                        if (item.count > 1) _CountChip(item.count),
                      ],
                    ),
                  ),
                  indicator: ReorderOrSelectIndicator(
                    index: index,
                    selectionMode: _selected.isNotEmpty,
                    selected: selected,
                  ),
                ),
              ),
            );
          },
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: OutlinedButton.icon(
              key: const Key('packingAddSection'),
              icon: const Icon(Icons.add),
              label: const Text('Add section'),
              onPressed: _addSection,
            ),
          ),
        ),
      ],
    );
  }
}

/// A view-mode row (Round 95: a normal size, as Shop's): the box, the
/// name, its count; a tap anywhere on it ticks it. Ticked, it's struck
/// through, in place.
class _TickRow extends StatelessWidget {
  final PackingItem item;
  final VoidCallback onTap;

  const _TickRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MergeSemantics(
      child: SelectableCard(
        key: Key('packingTick-${item.id}'),
        selected: false,
        onTap: onTap,
        child: Semantics(
          checked: item.packed,
          child: ConstrainedBox(
            constraints:
                const BoxConstraints(minHeight: kMinInteractiveDimension),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: kMinInteractiveDimension,
                  child: Icon(
                    item.packed
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    key: Key('packingBox-${item.id}'),
                    size: 22,
                    color: item.packed ? colors.accent : colors.textSecondary,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 15,
                        color:
                            item.packed ? colors.textMuted : colors.textPrimary,
                        decoration:
                            item.packed ? TextDecoration.lineThrough : null,
                        decorationColor: colors.textMuted,
                      ),
                    ),
                  ),
                ),
                if (item.count > 1)
                  Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: _CountChip(item.count, muted: item.packed),
                  ),
                const SizedBox(width: 12),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "× 3", how many of a thing.
class _CountChip extends StatelessWidget {
  final int count;
  final bool muted;

  const _CountChip(this.count, {this.muted = false});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: colors.background,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        '× $count',
        key: const Key('packingCount'),
        style: TextStyle(
          fontSize: 13,
          color: muted ? colors.textMuted : colors.textSecondary,
        ),
      ),
    );
  }
}

/// A thing's count (Round 94: just a count): big − and +, from 1 to
/// [PackingItem.maxCount]. Resolves to it when Set, null if closed.
Future<int?> showCountSheet(BuildContext context, PackingItem item) {
  var count = item.count;
  return showModalBottomSheet<int>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final colors = context.colors;
        Widget step(IconData icon, String tooltip, int by, Key key) =>
            IconButton.filledTonal(
              key: key,
              tooltip: tooltip,
              iconSize: 32,
              constraints: const BoxConstraints.tightFor(width: 64, height: 64),
              icon: Icon(icon),
              onPressed: (count + by).clamp(1, PackingItem.maxCount) == count
                  ? null
                  : () => setState(() => count += by),
            );
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(item.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colors.textSecondary)),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    step(Icons.remove, 'One less', -1,
                        const Key('packingCountLess')),
                    SizedBox(
                      width: 96,
                      child: Text(
                        '$count',
                        key: const Key('packingCountValue'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 32,
                          color: colors.textPrimary,
                        ),
                      ),
                    ),
                    step(Icons.add, 'One more', 1,
                        const Key('packingCountMore')),
                  ],
                ),
                const SizedBox(height: 16),
                FilledButton(
                  key: const Key('packingCountSet'),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  onPressed: () => Navigator.of(context).pop(count),
                  child: const Text('Set'),
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
