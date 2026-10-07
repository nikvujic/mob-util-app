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
/// Leaving with back after changing something asks "Save changes?":
/// Yes (or tapping outside the dialog) keeps them; No restores the note to
/// how it was when opened, or deletes a note created here. While editing an
/// existing note, ↶ restores that version without leaving the page.
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

  /// Set while [_onBack] handles leaving (asking, saving, closing).
  bool _leaving = false;

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

  /// Throws away everything done since the page was opened: restores the
  /// note, or deletes it if it was created here. Nothing is saved after.
  void _discardAll() {
    _discarded = true;
    _autosaveTimer?.cancel();
    final notifier = ref.read(notesProvider.notifier);
    final original = _original;
    if (widget.isNew || original == null) {
      notifier.removeNotes({widget.noteId});
    } else {
      notifier.restoreNote(original);
    }
  }

  /// Back (app bar arrow or system back).
  Future<void> _onBack() async {
    if (_leaving) return; // e.g. a second quick tap while the dialog opens
    _leaving = true;
    if (_hasChanges) {
      final save = await showSaveChangesDialog(
        context,
        title: widget.isNew ? 'Save new note?' : 'Save changes?',
      );
      if (!mounted) return;
      if (save) {
        _save();
      } else {
        _discardAll();
      }
    } else {
      _save(); // removes an untouched new note
    }
    Navigator.of(context).pop();
  }

  /// ↶ in the app bar: undo all edits but keep editing.
  Future<void> _revertInPlace() async {
    final original = _original;
    if (original == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'The note goes back to how it was when you opened it.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!confirmed || !mounted) return;

    _autosaveTimer?.cancel();
    ref.read(notesProvider.notifier).restoreNote(original);
    _titleController.text = original.title;
    _contentController.text = original.content;
    _autosaveTimer?.cancel(); // the text reset above scheduled one
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Back is handled by [_onBack] so it can ask before leaving.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          // Popped by other means than back (e.g. the app navigating away):
          // keep whatever was typed.
          if (!_leaving) _save();
          return;
        }
        _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Note'),
          actions: [
            if (!widget.isNew)
              ListenableBuilder(
                listenable: Listenable.merge(
                  [_titleController, _contentController],
                ),
                builder: (context, _) => IconButton(
                  icon: const Icon(Icons.undo),
                  tooltip: 'Discard changes',
                  onPressed: _hasChanges ? _revertInPlace : null,
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
