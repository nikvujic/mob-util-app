import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/packing.dart';
import 'package:the_app/pages/hub/packing.dart';
import 'package:the_app/pages/hub/packing_copy_sheet.dart';
import 'package:the_app/pages/hub/page_gate.dart';
import 'package:the_app/pages/hub/recipe_page.dart' show showChoicesSheet;
import 'package:the_app/providers/packing_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/low_handles.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';
import 'package:the_app/widgets/text_input_sheet.dart';

/// One packing list (Round 94). It opens in **view mode**: its items
/// under their sections, each with a big box; a tap anywhere on a row
/// ticks it (or unticks it), and ticked ones stay where they are.
/// **Reset** unticks them all. **Edit** makes it editable: its name; a
/// section's + adds items to it; an item's tap renames it, sets its count
/// or deletes it, and its handle drags it, into another section too.
/// Changes are saved as they're made; Undo steps back, Discard changes
/// goes back to how it was when Edit was pressed, Done returns to view
/// mode. A new list ([isNew]) opens in edit mode, and is dropped if left
/// with nothing in it.
class PackingListPage extends ConsumerStatefulWidget {
  final String listId;
  final bool isNew;

  const PackingListPage({super.key, required this.listId, this.isNew = false});

  @override
  ConsumerState<PackingListPage> createState() => _PackingListPageState();
}

class _PackingListPageState extends ConsumerState<PackingListPage> {
  static const _saveDelay = Duration(milliseconds: 600);

  /// Typing within this of the last change is the same Undo step.
  static const _burst = Duration(seconds: 1);

  late bool _editing = widget.isNew;

  /// The list as being edited (edit mode only; view mode shows what's
  /// stored).
  late PackingList _list;

  /// As it was when Edit was pressed: Discard changes goes back to it.
  PackingList? _original;

  /// Undo (in edit mode): the list before each change.
  final _history = <PackingList>[];
  DateTime? _lastTyped;

  late final TextEditingController _name;
  final _nameFocus = FocusNode();

  /// Set while undo or discard puts the name back in its field.
  bool _applying = false;

  /// Set once it's gone (deleted, or dropped empty): nothing more saved.
  bool _gone = false;

  Timer? _saveTimer;

  /// Kept from the start: saving on closing comes after `ref` is gone.
  late final PackingNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(packingProvider.notifier);
    _list = _notifier.byId(widget.listId) ??
        PackingList(id: widget.listId, name: '');
    if (_editing) _original = _list;
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
    final now = DateTime.now();
    final last = _lastTyped;
    if (last == null || now.difference(last) > _burst) _history.add(_list);
    _lastTyped = now;
    setState(() => _list = _list.copyWith(name: _name.text));
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _saveNow);
  }

  /// A change other than typing: its own Undo step, saved at once.
  void _change(PackingList next) {
    _history.add(_list);
    _lastTyped = null;
    setState(() => _list = next);
    _saveNow();
  }

  void _saveNow() {
    _saveTimer?.cancel();
    if (_gone || !_editing) return;
    _notifier.save(_list);
  }

  /// Shows [list] (undo, discard).
  void _show(PackingList list) {
    _applying = true;
    _name.text = list.name;
    _applying = false;
    setState(() => _list = list);
  }

  void _undo() {
    if (_history.isEmpty) return;
    _lastTyped = null;
    _show(_history.removeLast());
    _saveNow();
  }

  void _edit() => setState(() {
        _list = _notifier.byId(widget.listId) ?? _list;
        _applying = true;
        _name.text = _list.name;
        _applying = false;
        _original = _list;
        _history.clear();
        _lastTyped = null;
        _editing = true;
      });

  /// Done: saved, back to view mode; a list with nothing in it is dropped
  /// instead, and the page left.
  void _done() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_list.isEmpty) {
      _drop();
      return;
    }
    _saveNow();
    setState(() => _editing = false);
  }

  void _drop() {
    _gone = true;
    _saveTimer?.cancel();
    _notifier.remove({widget.listId});
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _discard() async {
    final original = _original;
    if (original == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'The list goes back to how it was when you pressed Edit.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    _saveTimer?.cancel();
    _history.clear();
    _lastTyped = null;
    _show(original);
    _notifier.save(original);
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
    _notifier.toggle(widget.listId, item.id);
  }

  void _reset() {
    final before = _notifier.reset(widget.listId);
    if (before == null) return;
    _toast('All unticked', undo: () => _notifier.save(before));
  }

  Future<void> _copy(PackingList list, List<PackingSection> sections) async {
    final picked = await showCopyListSheet(
      context,
      list: list,
      groups: list.grouped(sections),
    );
    if (picked == null || !mounted) return;
    final id = _notifier.copy(list.id, picked.name, picked.sectionIds);
    if (id == null) return;
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PageGate(
          page: HubTool.packing,
          child: PackingListPage(listId: id),
        ),
      ),
    );
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
    final removed = notifier.remove({widget.listId});
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

  Future<void> _more(PackingList list, List<PackingSection> sections) async {
    final choice = await showChoicesSheet(context, null, const [
      (Icons.copy_all_outlined, 'Copy list', 'copy'),
      (Icons.delete_outline, 'Delete', 'delete'),
    ]);
    if (!mounted) return;
    switch (choice) {
      case 'copy':
        await _copy(list, sections);
      case 'delete':
        _delete(list);
    }
  }

  // Edit mode's changes.

  void _leaveFields() => FocusManager.instance.primaryFocus?.unfocus();

  /// Why [name] can't go into [sectionId] (it's there), or null.
  String? _already(String name, PackingSection section, {String? except}) =>
      _list.named(name, section.id, except: except) == null
          ? null
          : '${name.trim()} is already in ${section.name}';

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

  PackingSection _sectionOf(PackingItem item, List<PackingSection> sections) =>
      sections.where((s) => s.id == item.sectionId).firstOrNull ??
      sections.last;

  Future<void> _itemOptions(
    PackingItem item,
    List<PackingSection> sections,
  ) async {
    _leaveFields();
    final choice = await showChoicesSheet(context, item.name, const [
      (Icons.edit_outlined, 'Rename', 'rename'),
      (Icons.numbers, 'Count', 'count'),
      (Icons.delete_outline, 'Delete', 'delete'),
    ]);
    if (!mounted) return;
    void replace(PackingItem next) => _change(_list.copyWith(items: [
          for (final i in _list.items)
            if (i.id == item.id) next else i,
        ]));
    switch (choice) {
      case 'rename':
        final name = await showTextInputSheet(
          context,
          hint: 'Item',
          initialValue: item.name,
          check: (name) =>
              _already(name, _sectionOf(item, sections), except: item.id),
        );
        if (name == null || name == item.name || !mounted) return;
        replace(item.copyWith(name: name));
      case 'count':
        final count = await showCountSheet(context, item);
        if (count == null || count == item.count || !mounted) return;
        replace(item.copyWith(count: count));
      case 'delete':
        final before = _list;
        _change(_list.copyWith(items: [
          for (final i in _list.items)
            if (i.id != item.id) i,
        ]));
        _toast('${item.name} removed', undo: () {
          if (!mounted || !_editing) return;
          _change(before.copyWith(name: _list.name));
        });
    }
  }

  /// Back: out of the name first, then edit mode (as Done), then the
  /// page.
  void _onBack() {
    if (_nameFocus.hasFocus) {
      _leaveFields();
      return;
    }
    _done();
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(packingProvider);
    final stored = book.byId(widget.listId);
    final list = _editing ? _list : (stored ?? _list);
    final name = list.name.trim();
    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _editing ? 'Edit list' : (name.isEmpty ? 'Untitled' : name),
          ),
        ),
        body: _editing
            ? _editBody(context, book.sections)
            : _viewBody(context, list, book.sections),
        floatingActionButton: _editing
            ? BottomActions(
                actions: [
                  BottomAction(
                    icon: Icons.settings_backup_restore,
                    tooltip: 'Discard changes',
                    enabled: _original != null && !_list.sameAs(_original!),
                    onPressed: _discard,
                  ),
                  BottomAction(
                    icon: Icons.undo,
                    tooltip: 'Undo',
                    enabled: _history.isNotEmpty,
                    onPressed: _undo,
                  ),
                  // Outermost, under the thumb.
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
                    onPressed: () => _more(list, book.sections),
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

  Widget _heading(String text, {Key? key, Widget? trailing}) {
    final label = Text(
      text,
      key: key,
      style: TextStyle(
        color: context.colors.accent,
        fontSize: 12,
        fontWeight: FontWeight.w600,
        letterSpacing: 1,
      ),
    );
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: kMinInteractiveDimension),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, trailing == null ? 16 : 4, 0),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: label,
              ),
            ),
            if (trailing != null) trailing,
          ],
        ),
      ),
    );
  }

  Widget _viewBody(
    BuildContext context,
    PackingList list,
    List<PackingSection> sections,
  ) {
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
        for (final (section, items) in list.grouped(sections)) ...[
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

  Widget _editBody(BuildContext context, List<PackingSection> sections) {
    final colors = context.colors;
    final rows = <Object>[
      for (final (section, items)
          in _list.grouped(sections, keepEmpty: true)) ...[section, ...items],
    ];
    return PullDownList(
      key: const Key('packingEdit'),
      bottomSpace: BottomActions.contentClearance,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: TextField(
              key: const Key('packingName'),
              selectionControls: lowHandles,
              controller: _name,
              focusNode: _nameFocus,
              autofocus: widget.isNew,
              textCapitalization: TextCapitalization.sentences,
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
            final next = _list.moved(sections, from, to);
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
              final count = _list.items
                  .where((i) =>
                      i.sectionId == row.id ||
                      (row.isOther &&
                          !sections.any((s) => s.id == i.sectionId)))
                  .length;
              return KeyedSubtree(
                key: ValueKey('section-${row.id}'),
                child: _heading(
                  '${row.name.toUpperCase()}  ·  $count',
                  key: Key('packingSection-${row.id}'),
                  trailing: IconButton(
                    key: Key('packingAdd-${row.id}'),
                    tooltip: 'Add to ${row.name}',
                    icon: Icon(Icons.add, color: colors.accent),
                    onPressed: () => _addTo(row),
                  ),
                ),
              );
            }
            final item = row as PackingItem;
            return Padding(
              key: ValueKey(item.id),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
              child: SelectableCard(
                key: Key('packingItem-${item.id}'),
                selected: false,
                onTap: () => _itemOptions(item, sections),
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
                    selectionMode: false,
                    selected: false,
                  ),
                ),
              ),
            );
          },
        ),
      ],
    );
  }
}

/// A view-mode row (Nikola: convenient): a big box, the name, its count;
/// a tap anywhere on it ticks it. Ticked, it's struck through, in place.
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
            constraints: const BoxConstraints(minHeight: 56),
            child: Row(
              children: [
                SizedBox.square(
                  dimension: 56,
                  child: Icon(
                    item.packed
                        ? Icons.check_box
                        : Icons.check_box_outline_blank,
                    key: Key('packingBox-${item.id}'),
                    size: 30,
                    color: item.packed ? colors.accent : colors.textSecondary,
                  ),
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 16,
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
                const SizedBox(width: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// "× 3", how many of an item.
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

/// An item's count (Round 94: just a count): big − and +, from 1 to
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
