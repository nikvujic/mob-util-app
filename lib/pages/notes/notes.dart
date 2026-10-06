import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/pages/notes/note_detail.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/selection.dart';

class NotesPage extends ConsumerStatefulWidget {
  const NotesPage({super.key});

  @override
  ConsumerState<NotesPage> createState() => _NotesPageState();
}

class _NotesPageState extends ConsumerState<NotesPage> {
  final SelectionController _selection = SelectionController();

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _openNote(String id, {bool isNew = false}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => NoteDetailPage(noteId: id, isNew: isNew),
      ),
    );
  }

  void _createNote() {
    final id = ref.read(notesProvider.notifier).addNote();
    _openNote(id, isNew: true);
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

  @override
  Widget build(BuildContext context) {
    final notes = ref.watch(notesProvider);
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
                )
              : AppBar(
                  title: const Text('Notes'),
                  actions: [
                    PopupMenuButton<String>(
                      iconColor: AppColors.textPrimary,
                      onSelected: (value) {
                        // TODO: export / import (requirement N8).
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(
                          value: 'export',
                          child: Text('Export Notes'),
                        ),
                        PopupMenuItem(
                          value: 'import',
                          child: Text('Import Notes'),
                        ),
                      ],
                    ),
                  ],
                ),
          body: notes.isEmpty
              ? const EmptyState(icon: Icons.note_outlined, message: 'No notes')
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
                          () => _openNote(note.id),
                        ),
                        onLongPress: () =>
                            _selection.handleLongPress(note.id),
                      ),
                    );
                  },
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
                    Text(
                      note.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      _formatModifiedTime(note.modifiedAt),
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

String _formatModifiedTime(DateTime dt) {
  final mo = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');
  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');
  return '${dt.year}-$mo-$d  $h:$m';
}
