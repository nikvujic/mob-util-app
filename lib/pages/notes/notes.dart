import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/pages/notes/note_detail.dart';
import 'package:the_app/providers/notes_provider.dart';

class NotesPage extends ConsumerWidget {
  const NotesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notes = [...ref.watch(notesProvider)];
    notes.sort((a, b) => b.modifiedAt.compareTo(a.modifiedAt));

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.grey[900],
        title: const Text('Notes', style: TextStyle(color: Colors.white)),
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        actions: [
          PopupMenuButton<String>(
            color: Colors.grey[800],
            iconColor: Colors.white,
            onSelected: (value) {
              if (value == 'export') {
                // Handle export
              } else if (value == 'import') {
                // Handle import
              }
            },
            itemBuilder: (BuildContext context) {
              return const [
                PopupMenuItem(
                  value: 'export',
                  child: Text('Export Notes',
                      style: TextStyle(color: Colors.white)),
                ),
                PopupMenuItem(
                  value: 'import',
                  child: Text('Import Notes',
                      style: TextStyle(color: Colors.white)),
                ),
              ];
            },
          ),
        ],
      ),
      body: notes.isEmpty
          ? const Center(
              child: Text('No notes',
                  style: TextStyle(color: Colors.white54, fontSize: 16)),
            )
          : Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: ListView.builder(
                itemCount: notes.length,
                physics: const RangeMaintainingScrollPhysics(),
                itemBuilder: (context, index) {
                  final note = notes[index];

                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Card(
                      color: Colors.grey[850],
                      shape: const RoundedRectangleBorder(
                          borderRadius: BorderRadius.all(Radius.circular(6))),
                      margin: EdgeInsets.zero,
                      child: Theme(
                        data: Theme.of(context).copyWith(
                          splashColor: Colors.transparent,
                          highlightColor: Colors.transparent,
                          hoverColor: Colors.transparent
                        ),
                        child: ListTile(
                          title: Text(note.title,
                              style: const TextStyle(color: Colors.white)),
                          subtitle: Text(
                            _formatModifiedTime(note.modifiedAt),
                            style: TextStyle(color: Colors.grey[400], fontSize: 12),
                          ),
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => NoteDetailPage(
                                  noteId: note.id,
                                  isNew: false,
                                ),
                              ),
                            );
                          },
                          onLongPress: () {
                            ref
                                .read(notesProvider.notifier)
                                .removeNote(note.id);
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.green,
        shape: const CircleBorder(),
        onPressed: () {
          Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => const NoteDetailPage(
                noteId: null,
                isNew: true,
              ),
            ),
          );
        },
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }
}

String _formatModifiedTime(DateTime dt) {
  final y = dt.year;
  final mo = dt.month.toString().padLeft(2, '0');
  final d = dt.day.toString().padLeft(2, '0');

  final h = dt.hour.toString().padLeft(2, '0');
  final m = dt.minute.toString().padLeft(2, '0');

  return '$y-$mo-$d  $h:$m';
}