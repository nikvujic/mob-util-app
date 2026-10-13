import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/todo_item.dart';
import 'package:the_app/providers/todo_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';
import 'package:the_app/widgets/text_input_sheet.dart';

/// Opens the to-do note (Round 28).
void openTodo(BuildContext context) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(builder: (_) => const TodoPage()),
  );
}

/// The to-do note (Round 28): like Shop, two lists (Round 30): the things
/// to do, and *Completed* below. Tapping one moves it to the other list;
/// holding one changes its text; the handle moves it within its list.
/// The buttons sit on the hand's side; *Delete completed* clears the
/// lower list.
class TodoPage extends ConsumerStatefulWidget {
  const TodoPage({super.key});

  @override
  ConsumerState<TodoPage> createState() => _TodoPageState();
}

class _TodoPageState extends ConsumerState<TodoPage> {
  /// The thing added last, scrolled into view above the add sheet.
  String? _addedId;
  final _addedKey = GlobalKey();

  /// About how much of the list the add sheet covers.
  static const _sheetHeight = 80.0;

  TodoNotifier get _notifier => ref.read(todoProvider.notifier);

  void _addItems() {
    showTextInputSheet(
      context,
      hint: 'Add a to-do',
      submitLabel: 'Add',
      keepOpen: true,
      onSubmit: _add,
    );
  }

  /// Adds one and scrolls to it, so it's seen landing in the list.
  void _add(String text) {
    final id = _notifier.add(text);
    if (id == null) return;
    setState(() => _addedId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _addedKey.currentContext;
      if (row != null && mounted) {
        PullDownList.reveal(row, obscuredBottom: _sheetHeight);
      }
    });
  }

  void _toggle(TodoItem item) {
    HapticFeedback.lightImpact();
    _notifier.toggle(item.id);
  }

  void _edit(TodoItem item) {
    showTextInputSheet(
      context,
      hint: 'To-do',
      initialValue: item.text,
      onSubmit: (text) => _notifier.edit(item.id, text),
    );
  }

  /// Asked first, and it can't be undone (so no Undo after).
  Future<void> _deleteCompleted(int count) async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      count: count,
      singular: 'completed to-do',
      plural: 'completed to-dos',
    );
    if (!confirmed || !mounted) return;
    _notifier.deleteCompleted();
  }

  Widget _section(List<TodoItem> items, {required bool done}) {
    return SliverReorderableList(
      itemCount: items.length,
      // onReorderItem only exists on newer Flutter than we target.
      // ignore: deprecated_member_use
      onReorder: (oldIndex, newIndex) => _notifier.reorder(
        done: done,
        oldIndex: oldIndex,
        newIndex: newIndex,
      ),
      proxyDecorator: (child, _, __) => Material(
        type: MaterialType.transparency,
        elevation: 6,
        child: child,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          key: ValueKey(item.id),
          padding: const EdgeInsets.symmetric(vertical: 2),
          child: _TodoRow(
            key: item.id == _addedId ? _addedKey : null,
            item: item,
            index: index,
            onTap: () => _toggle(item),
            // Only the ones to do can be changed (Round 33).
            onLongPress: done ? null : () => _edit(item),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(todoProvider);
    final open = [
      for (final i in items)
        if (!i.done) i
    ];
    final done = [
      for (final i in items)
        if (i.done) i
    ];
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('To-do')),
      body: items.isEmpty
          ? const EmptyState(icon: Icons.checklist, message: 'Nothing to do')
          : PullDownList(
              bottomSpace: BottomActions.contentClearance,
              // Rows stay built, so a new one can be scrolled to.
              cacheExtent: 10000,
              slivers: [
                _SectionHeader(title: 'To do', count: open.length),
                if (open.isEmpty)
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      child: Text(
                        'Nothing to do',
                        style: TextStyle(color: colors.textMuted),
                      ),
                    ),
                  ),
                _section(open, done: false),
                if (done.isNotEmpty) ...[
                  _SectionHeader(
                    title: 'Completed',
                    count: done.length,
                    // Quietly beside its list (Round 33: a red round
                    // button looked out of place).
                    action: TextButton(
                      key: const Key('deleteCompleted'),
                      onPressed: () => _deleteCompleted(done.length),
                      child: const Text('Delete all'),
                    ),
                  ),
                  _section(done, done: true),
                ],
              ],
            ),
      floatingActionButton: BottomActions(
        actions: [
          BottomAction(
            icon: Icons.add,
            tooltip: 'Add a to-do',
            primary: true,
            onPressed: _addItems,
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  /// A button at its end, if any.
  final Widget? action;

  const _SectionHeader({required this.title, required this.count, this.action});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, action == null ? 12 : 4, 8, 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                '${title.toUpperCase()}  ·  $count',
                style: TextStyle(
                  color: context.colors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            if (action case final action?) action,
          ],
        ),
      ),
    );
  }
}

/// A compact row, like Shop's: an empty circle (done: a tick), the text,
/// the handle. A tap anywhere on it moves it to the other list.
class _TodoRow extends StatelessWidget {
  final TodoItem item;
  final int index;
  final VoidCallback onTap;
  final VoidCallback? onLongPress;

  const _TodoRow({
    super.key,
    required this.item,
    required this.index,
    required this.onTap,
    this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return MergeSemantics(
      child: SelectableCard(
        selected: false,
        onTap: onTap,
        onLongPress: onLongPress,
        child: ReorderableRow(
          content: Row(
            children: [
              Semantics(
                checked: item.done,
                child: SizedBox.square(
                  dimension: kMinInteractiveDimension,
                  child: Icon(
                    item.done ? Icons.check : Icons.radio_button_unchecked,
                    size: 22,
                    color: item.done ? colors.textSecondary : colors.accent,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item.text,
                  style: TextStyle(
                    fontSize: 15,
                    color:
                        item.done ? colors.textSecondary : colors.textPrimary,
                    decoration: item.done ? TextDecoration.lineThrough : null,
                    decorationColor: colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          indicator: ReorderOrSelectIndicator(
            index: index,
            selectionMode: false,
            selected: false,
          ),
        ),
      ),
    );
  }
}

/// The to-do note at the top of Notes (Round 28): a note of its own kind,
/// not selectable or movable, showing how many things are left.
class TodoTile extends ConsumerWidget {
  /// Selection mode is on in the list: it takes no part (taps do nothing).
  final bool selectionMode;

  const TodoTile({super.key, required this.selectionMode});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // What's left to do (Round 30: done ones stay, in Completed).
    final items = [
      for (final i in ref.watch(todoProvider))
        if (!i.done) i,
    ];
    final colors = context.colors;
    return SelectableCard(
      key: const Key('todoTile'),
      selected: false,
      onTap: selectionMode ? null : () => openTodo(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Icon(Icons.checklist, color: colors.accent),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'To-do',
                    style: TextStyle(color: colors.textPrimary, fontSize: 16),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    key: const Key('todoSummary'),
                    items.isEmpty ? 'Nothing to do' : items.first.text,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: colors.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),
            if (items.isNotEmpty)
              Text(
                key: const Key('todoCount'),
                '${items.length}',
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
