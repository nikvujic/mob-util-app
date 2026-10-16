import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/todo_item.dart';
import 'package:the_app/providers/fingerprint_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/section_locks_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/providers/todo_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/locked_screen.dart';
import 'package:the_app/widgets/password_prompt.dart';
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
///
/// Its options (Round 45, the button beside Add): a *Waiting* list under
/// the things to do, things dragged into it and back (a tap still
/// completes one); and a lock, closing the note while the app is locked,
/// as a Hub page's lock does.
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

  Future<void> _options() => showModalBottomSheet<void>(
        context: context,
        builder: (_) => const _TodoOptions(),
      );

  /// *To do* and *Waiting* as one list (Round 45), so things can be
  /// dragged between them: [open], the Waiting header, then [waiting].
  Widget _openAndWaiting(List<TodoItem> open, List<TodoItem> waiting) {
    final count = open.length + 1 + waiting.length;
    return SliverReorderableList(
      itemCount: count,
      // onReorderItem only exists on newer Flutter than we target.
      // ignore: deprecated_member_use
      onReorder: (oldIndex, newIndex) {
        // The header (null) is never dragged: it has no handle.
        final rows = <String?>[
          for (final i in open) i.id,
          null,
          for (final i in waiting) i.id,
        ];
        if (newIndex > oldIndex) newIndex--;
        rows.insert(newIndex, rows.removeAt(oldIndex));
        final header = rows.indexOf(null);
        _notifier.place(
          toDo: [for (final id in rows.take(header)) id!],
          waiting: [for (final id in rows.skip(header + 1)) id!],
        );
      },
      proxyDecorator: (child, _, __) => Material(
        type: MaterialType.transparency,
        elevation: 6,
        child: child,
      ),
      itemBuilder: (context, index) {
        if (index == open.length) {
          return _WaitingHeader(
            key: const ValueKey('waitingHeader'),
            count: waiting.length,
          );
        }
        final inWaiting = index > open.length;
        final item = inWaiting ? waiting[index - open.length - 1] : open[index];
        return _row(item, index, done: false);
      },
    );
  }

  Widget _row(TodoItem item, int index, {required bool done}) {
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
      itemBuilder: (context, index) => _row(items[index], index, done: done),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(todoClosedProvider)) {
      return LockedScreen(
        title: 'To-do',
        askAtOnce: true,
        appBar: AppBar(title: const Text('To-do')),
        onUnlock: () => showPasswordPrompt<UnlockedKeys>(
          context,
          title: 'Unlock',
          confirmLabel: 'Unlock',
          attempt: ref.read(sessionProvider.notifier).unlock,
          alternative: PromptAlternative.fingerprint(
            attempt: ref.read(fingerprintProvider.notifier).unlock,
            isOffered: () => ref.read(fingerprintProvider),
          ),
        ),
      );
    }
    final items = ref.watch(todoProvider);
    final waitingList =
        ref.watch(preferencesProvider.select((p) => p.todoWaiting));
    // With the Waiting list off, waiting things stay with the rest.
    final open = [
      for (final i in items)
        if (!i.done && !(waitingList && i.waiting)) i
    ];
    final waiting = [
      for (final i in items)
        if (!i.done && waitingList && i.waiting) i
    ];
    final done = [
      for (final i in items)
        if (i.done) i
    ];
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('To-do')),
      body: items.isEmpty && !waitingList
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
                if (waitingList)
                  _openAndWaiting(open, waiting)
                else
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
            icon: Icons.tune,
            tooltip: 'To-do options',
            onPressed: _options,
          ),
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

/// The *Waiting* list's header (Round 45), a row of the to-do list so
/// things can be dragged past it; empty, it says what it's for.
class _WaitingHeader extends StatelessWidget {
  final int count;

  const _WaitingHeader({super.key, required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'WAITING  ·  $count',
            style: TextStyle(
              color: colors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
          if (count == 0)
            Padding(
              padding: const EdgeInsets.only(top: 8, bottom: 4),
              child: Text(
                "Drag here what you're waiting on",
                style: TextStyle(color: colors.textMuted),
              ),
            ),
        ],
      ),
    );
  }
}

/// The to-do note's options (Round 45): the *Waiting* list, and the lock.
class _TodoOptions extends ConsumerWidget {
  const _TodoOptions();

  Future<void> _setLock(BuildContext context, WidgetRef ref, bool on) async {
    final lock = ref.read(todoLockProvider.notifier);
    if (on) {
      lock.lock();
      return;
    }
    // Open here, the app is unlocked (or the note isn't locked).
    try {
      lock.unlock();
    } on AppLockedException {
      // Locked meanwhile: the page closes; nothing to change.
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final waiting = ref.watch(preferencesProvider.select((p) => p.todoWaiting));
    final hasPassword = ref.watch(securityProvider) != null;
    final locked = ref.watch(todoLockProvider);
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'To-do options',
                style: TextStyle(color: colors.textSecondary, fontSize: 14),
              ),
            ),
          ),
          SwitchListTile(
            key: const Key('todoWaiting'),
            secondary: const Icon(Icons.hourglass_empty),
            title: const Text('Waiting list'),
            subtitle: Text(
              "Things you're waiting on, in a list of their own. Off, "
              'they show with the rest.',
              style: TextStyle(color: colors.textSecondary),
            ),
            value: waiting,
            onChanged: ref.read(preferencesProvider.notifier).setTodoWaiting,
          ),
          SwitchListTile(
            key: const Key('todoLock'),
            secondary: Icon(locked ? Icons.lock_outline : Icons.lock_open),
            title: const Text('Lock'),
            subtitle: Text(
              hasPassword
                  ? 'Opens only while the app is unlocked'
                  : 'Set a master password first',
              style: TextStyle(color: colors.textSecondary),
            ),
            value: locked,
            onChanged: hasPassword ? (on) => _setLock(context, ref, on) : null,
          ),
        ],
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
                  // Waiting (Round 45): an hourglass, wherever it shows.
                  child: Icon(
                    item.done
                        ? Icons.check
                        : item.waiting
                            ? Icons.hourglass_empty
                            : Icons.radio_button_unchecked,
                    key: item.waiting ? Key('waiting-${item.id}') : null,
                    size: 22,
                    color: item.done || item.waiting
                        ? colors.textSecondary
                        : colors.accent,
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
    // Closed by its lock (Round 45): nothing of it shown.
    final closed = ref.watch(todoClosedProvider);
    // What's left to do (Round 30: done ones stay, in Completed); waiting
    // ones (Round 45) count, but the summary names one to do first.
    final items = closed
        ? const <TodoItem>[]
        : [
            for (final i in ref.watch(todoProvider))
              if (!i.done) i,
          ];
    final first =
        items.where((i) => !i.waiting).firstOrNull ?? items.firstOrNull;
    final colors = context.colors;
    return SelectableCard(
      key: const Key('todoTile'),
      selected: false,
      onTap: selectionMode ? null : () => openTodo(context),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Row(
          children: [
            Icon(closed ? Icons.lock_outline : Icons.checklist,
                color: colors.accent),
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
                    closed ? 'Locked' : first?.text ?? 'Nothing to do',
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
