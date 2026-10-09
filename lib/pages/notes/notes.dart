import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/pages/notes/note_detail.dart';
import 'package:the_app/pages/notes/note_keys.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/security_provider.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/main_app_bar.dart';
import 'package:the_app/widgets/selection.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  final SelectionController _selection = SelectionController();

  /// A note just created and opened: it exists (and is saved) right away,
  /// but the list only shows it once the editor fully covers the list, so
  /// the list doesn't visibly shift while the editor slides in.
  String? _arrivingId;

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  /// Opens a note; a locked one is decrypted first, asking for the master
  /// password if the app is locked.
  Future<void> _openNote(Note note) async {
    ({String content, DataKey key})? unlocked;
    if (note.isLocked) {
      final key = await unlockNotesKey(
        context,
        ref,
        message: 'Enter the master password to open this note.',
      );
      if (!mounted) return;
      if (key == null) {
        if (ref.read(securityProvider) == null) {
          _showMessage('This note is locked, but no master password is set.');
        }
        return;
      }
      try {
        final content =
            await ref.read(notesProvider.notifier).readContent(note, key);
        unlocked = (content: content, key: key);
      } on DecryptionException {
        if (mounted) {
          _showMessage("This note can't be opened with your master password.");
        }
        return;
      }
      if (!mounted) return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteDetailPage(noteId: note.id, unlocked: unlocked),
      ),
    );
  }

  void _createNote() {
    final id = ref.read(notesProvider.notifier).addNote();
    setState(() => _arrivingId = id);

    final route = MaterialPageRoute<void>(
      builder: (_) => NoteDetailPage(noteId: id, isNew: true),
    );
    Navigator.of(context).push(route);

    // Reveal the note once the editor is fully open (or its opening was
    // cancelled).
    final animation = route.animation!;
    void reveal(AnimationStatus status) {
      if (status != AnimationStatus.completed &&
          status != AnimationStatus.dismissed) {
        return;
      }
      animation.removeStatusListener(reveal);
      if (mounted && _arrivingId == id) setState(() => _arrivingId = null);
    }

    animation.addStatusListener(reveal);
  }

  /// Selection → Lock: locks every selected note that isn't yet.
  Future<void> _lockSelected() async {
    final key = await lockingKey(context, ref);
    if (key == null || !mounted) return;
    final notifier = ref.read(notesProvider.notifier);
    final ids = _selection.selected;
    for (final id in ids) {
      await notifier.lockNote(id, key);
    }
    if (!mounted) return;
    _selection.clear();
    _showMessage('${countOf(ids.length, 'note', 'notes')} locked');
  }

  /// Selection → Remove lock (only offered when all selected are locked).
  Future<void> _removeLockSelected() async {
    final count = _selection.count;
    final confirmed = await showConfirmDialog(
      context,
      title: count == 1 ? 'Remove lock?' : 'Remove lock from $count notes?',
      message: 'Unlocked notes are stored unencrypted and open without the '
          'master password.',
      confirmLabel: 'Remove lock',
    );
    if (!confirmed || !mounted) return;
    final key = await unlockNotesKey(context, ref);
    if (key == null || !mounted) return;
    final notifier = ref.read(notesProvider.notifier);
    var failed = 0;
    for (final id in _selection.selected) {
      try {
        await notifier.unlockNote(id, key);
      } on DecryptionException {
        failed++;
      }
    }
    if (!mounted) return;
    _selection.clear();
    if (failed > 0) {
      _showMessage(
        "Couldn't remove the lock from ${countOf(failed, 'note', 'notes')}: "
        "your master password doesn't open them.",
      );
    }
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      count: _selection.count,
      singular: 'note',
      plural: 'notes',
    );
    if (!confirmed || !mounted) return;
    ref.read(notesProvider.notifier).removeNotes(_selection.selected);
    _selection.clear();
  }

  bool _allSelectedLocked(List<Note> notes) =>
      notes.where((n) => _selection.isSelected(n.id)).every((n) => n.isLocked);

  @override
  Widget build(BuildContext context) {
    final allNotes = ref.watch(notesProvider);
    final notes = _arrivingId == null
        ? allNotes
        : allNotes.where((n) => n.id != _arrivingId).toList();
    ref.listen(notesProvider, (_, next) {
      _selection.retain(next.map((n) => n.id));
    });

    return SelectionPopScope(
      controller: _selection,
      child: ListenableBuilder(
        listenable: _selection,
        builder: (context, _) => Scaffold(
          appBar: _selection.isActive
              ? SelectionAppBar(
                  count: _selection.count,
                  allSelected: _selection.count == notes.length,
                  onClose: _selection.clear,
                  onSelectAll: () =>
                      _selection.selectAll(notes.map((n) => n.id)),
                  onDelete: _deleteSelected,
                  actions: [
                    _allSelectedLocked(notes)
                        ? IconButton(
                            icon: const Icon(Icons.lock_open_outlined),
                            tooltip: 'Remove lock',
                            onPressed: _removeLockSelected,
                          )
                        : IconButton(
                            icon: const Icon(Icons.lock_outline),
                            tooltip: 'Lock',
                            onPressed: _lockSelected,
                          ),
                  ],
                )
              : const MainAppBar(title: 'Notes'),
          // Not interactive while a new note is hidden, so list positions
          // always match the stored order.
          body: IgnorePointer(
            ignoring: _arrivingId != null,
            child: notes.isEmpty
                ? const EmptyState(
                    icon: Icons.note_outlined, message: 'No notes')
                : ReorderableListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    buildDefaultDragHandles: false,
                    itemCount: notes.length,
                    // onReorderItem only exists on newer Flutter than we target.
                    // ignore: deprecated_member_use
                    onReorder: ref.read(notesProvider.notifier).reorder,
                    itemBuilder: (context, index) {
                      final note = notes[index];
                      return Padding(
                        key: ValueKey(note.id),
                        padding: const EdgeInsets.symmetric(vertical: 4),
                        child: _NoteTile(
                          note: note,
                          index: index,
                          selectionMode: _selection.isActive,
                          selected: _selection.isSelected(note.id),
                          onTap: () => _selection.handleTap(
                            note.id,
                            () => _openNote(note),
                          ),
                          onLongPress: () =>
                              _selection.handleLongPress(note.id),
                        ),
                      );
                    },
                  ),
          ),
          floatingActionButton: _selection.isActive
              ? null
              : FloatingActionButton(
                  // Tabs are kept alive side by side; a shared default hero
                  // tag would clash when a route is pushed.
                  heroTag: null,
                  tooltip: 'New note',
                  onPressed: _createNote,
                  child: const Icon(Icons.add),
                ),
        ),
      ),
    );
  }
}

class _NoteTile extends StatelessWidget {
  final Note note;
  final int index;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _NoteTile({
    required this.note,
    required this.index,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableCard(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Padding(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        if (note.isLocked) ...[
                          const Icon(
                            Icons.lock_outline,
                            size: 16,
                            color: AppColors.textSecondary,
                            semanticLabel: 'Locked',
                          ),
                          const SizedBox(width: 6),
                        ],
                        Flexible(
                          child: Text(
                            note.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formatDateTime(note.modifiedAt),
                      style: const TextStyle(
                        color: AppColors.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ReorderOrSelectIndicator(
              index: index,
              selectionMode: selectionMode,
              selected: selected,
            ),
          ],
        ),
      ),
    );
  }
}
