import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/widgets/confirm_dialog.dart';

/// Shows and edits a single note.
///
/// Changes are saved shortly after typing stops, when the app goes to the
/// background, and when the page is left. A note created just now ([isNew])
/// that is left untouched — default title and no content — is deleted again
/// when the page is left.
///
/// "Discard changes" undoes everything done since the page was opened: the
/// note is restored to that version (or removed, if it was created here).
class NoteDetailPage extends ConsumerStatefulWidget {
  final String noteId;
  final bool isNew;

  const NoteDetailPage({super.key, required this.noteId, this.isNew = false});

  @override
  ConsumerState<NoteDetailPage> createState() => _NoteDetailPageState();
}

class _NoteDetailPageState extends ConsumerState<NoteDetailPage> {
  static const _untitled = 'Untitled';
  static const _autosaveDelay = Duration(milliseconds: 600);

  late final TextEditingController _titleController;
  late final TextEditingController _contentController;
  final FocusNode _contentFocusNode = FocusNode();
  late final AppLifecycleListener _lifecycleListener;
  Timer? _autosaveTimer;

  /// The note as it was when the page opened, for "Discard changes".
  Note? _original;

  /// Set once changes are discarded, so leaving the page saves nothing.
  bool _discarded = false;

  @override
  void initState() {
    super.initState();
    _original =
        ref.read(notesProvider).where((n) => n.id == widget.noteId).firstOrNull;
    _titleController = TextEditingController(text: _original?.title ?? '');
    _contentController = TextEditingController(text: _original?.content ?? '');
    _titleController.addListener(_scheduleAutosave);
    _contentController.addListener(_scheduleAutosave);
    _lifecycleListener = AppLifecycleListener(onHide: _autosave);
  }

  @override
  void dispose() {
    _autosaveTimer?.cancel();
    _lifecycleListener.dispose();
    _titleController.dispose();
    _contentController.dispose();
    _contentFocusNode.dispose();
    super.dispose();
  }

  void _scheduleAutosave() {
    _autosaveTimer?.cancel();
    _autosaveTimer = Timer(_autosaveDelay, _autosave);
  }

  /// Saves work in progress. Unlike [_save] it never deletes the note, and
  /// a cleared title is not saved until the user leaves the page.
  void _autosave() {
    _autosaveTimer?.cancel();
    if (_discarded) return;
    final title = _titleController.text.trim();
    ref.read(notesProvider.notifier).updateNote(
          widget.noteId,
          title: title.isEmpty ? null : title,
          content: _contentController.text,
        );
  }

  void _save() {
    _autosaveTimer?.cancel();
    if (_discarded) return;
    final title = _titleController.text.trim();
    final content = _contentController.text;
    final notifier = ref.read(notesProvider.notifier);

    final untouched = (title.isEmpty || title == NotesNotifier.defaultTitle) &&
        content.trim().isEmpty;
    if (widget.isNew && untouched) {
      notifier.removeNotes({widget.noteId});
      return;
    }

    notifier.updateNote(
      widget.noteId,
      title: title.isEmpty ? _untitled : title,
      content: content,
    );
  }

  bool get _hasChanges =>
      _titleController.text != (_original?.title ?? '') ||
      _contentController.text != (_original?.content ?? '');

  Future<void> _discardChanges() async {
    final confirmed = await showConfirmDialog(
      context,
      title: widget.isNew ? 'Discard this note?' : 'Discard changes?',
      message: widget.isNew
          ? 'The new note will be deleted.'
          : 'The note goes back to how it was when you opened it.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    _discarded = true;
    _autosaveTimer?.cancel();
    final notifier = ref.read(notesProvider.notifier);
    final original = _original;
    if (widget.isNew || original == null) {
      notifier.removeNotes({widget.noteId});
    } else {
      notifier.restoreNote(original);
    }
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) _save();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Note'),
          actions: [
            ListenableBuilder(
              listenable: Listenable.merge(
                [_titleController, _contentController],
              ),
              builder: (context, _) => IconButton(
                icon: const Icon(Icons.undo),
                tooltip: 'Discard changes',
                onPressed: _hasChanges ? _discardChanges : null,
              ),
            ),
          ],
        ),
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: TextField(
                key: const Key('noteTitleField'),
                controller: _titleController,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.next,
                onSubmitted: (_) => _contentFocusNode.requestFocus(),
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Title',
                  hintStyle: TextStyle(color: AppColors.textHint),
                ),
              ),
            ),
            const Divider(height: 1, color: AppColors.divider),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                child: TextField(
                  key: const Key('noteContentField'),
                  controller: _contentController,
                  focusNode: _contentFocusNode,
                  autofocus: widget.isNew,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  expands: true,
                  textAlignVertical: TextAlignVertical.top,
                  style: const TextStyle(
                    color: AppColors.textPrimary,
                    fontSize: 16,
                  ),
                  decoration: const InputDecoration(
                    border: InputBorder.none,
                    hintText: 'Start writing…',
                    hintStyle: TextStyle(color: AppColors.textHint),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
