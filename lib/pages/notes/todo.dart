import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/todo_item.dart';
import 'package:the_app/providers/todo_provider.dart';
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

/// The to-do note (Round 28): a plain list, like Shop without its
/// sections. Tapping a thing marks it done: it goes, with "Task completed"
/// and Undo. Holding one changes its text; the handle moves it.
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

  void _complete(TodoItem item) {
    final notifier = _notifier;
    final at = notifier.complete(item.id);
    if (at == null) return;
    HapticFeedback.lightImpact();
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: const Text('Task completed'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => notifier.restore(item, at),
          ),
        ),
      );
  }

  void _edit(TodoItem item) {
    showTextInputSheet(
      context,
      hint: 'To-do',
      initialValue: item.text,
      onSubmit: (text) => _notifier.edit(item.id, text),
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(todoProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('To-do')),
      body: items.isEmpty
          ? const EmptyState(icon: Icons.checklist, message: 'Nothing to do')
          : PullDownList(
              bottomSpace: SelectionActions.listBottomSpace,
              // Rows stay built, so a new one can be scrolled to.
              cacheExtent: 10000,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(top: 8),
                  sliver: SliverReorderableList(
                    itemCount: items.length,
                    // onReorderItem only exists on newer Flutter than we
                    // target.
                    // ignore: deprecated_member_use
                    onReorder: _notifier.reorder,
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
                          onTap: () => _complete(item),
                          onLongPress: () => _edit(item),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
      floatingActionButton: FloatingActionButton(
        heroTag: null,
        tooltip: 'Add a to-do',
        onPressed: _addItems,
        child: const Icon(Icons.add),
      ),
    );
  }
}

/// A compact row, like Shop's: an empty circle (tap anywhere: done), the
/// text, the handle.
class _TodoRow extends StatelessWidget {
  final TodoItem item;
  final int index;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _TodoRow({
    super.key,
    required this.item,
    required this.index,
    required this.onTap,
    required this.onLongPress,
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
                checked: false,
                child: SizedBox.square(
                  dimension: kMinInteractiveDimension,
                  child: Icon(
                    Icons.radio_button_unchecked,
                    size: 22,
                    color: colors.accent,
                  ),
                ),
              ),
              Expanded(
                child: Text(
                  item.text,
                  style: TextStyle(fontSize: 15, color: colors.textPrimary),
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
    final items = ref.watch(todoProvider);
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
