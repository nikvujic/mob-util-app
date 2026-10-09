import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/pages/notes/note_keys.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/widgets/confirm_dialog.dart';

/// Shows and edits a single note.
///
/// Changes are saved shortly after typing stops, when the app goes to the
/// background, and when the page is left. A note created just now ([isNew])
/// that is left untouched — default title and no content — is deleted again
/// when the page is left.
///
/// Leaving with back after changing something asks "Save changes?":
/// Save (or tapping outside the dialog) keeps them; Discard restores the
/// note to how it was when opened, or deletes a note created here. While
/// editing an existing note, ↶ restores that version without leaving the
/// page.
///
/// A locked note (N6) is opened with its content already decrypted
/// ([unlocked]); edits are saved encrypted with the same key. If the app
/// locks while it's open (L4), the note is saved and closed. Locking and
/// removing the lock (⋮ menu) take effect at once and count as saving:
/// Discard afterwards goes back only to that point.
class NoteDetailPage extends ConsumerStatefulWidget {
  final String noteId;
  final bool isNew;

  /// For a locked note: its decrypted content and the key to save it with.
  final ({String content, DataKey key})? unlocked;

  const NoteDetailPage({
    super.key,
    required this.noteId,
    this.isNew = false,
    this.unlocked,
  });

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

  /// The note as it was when the page opened (or was last locked or
  /// unlocked here), for "Discard changes"; and its text, which for a
  /// locked note isn't in [Note.content].
  Note? _original;
  String _originalContent = '';

  /// The key for locked notes, once known.
  DataKey? _key;

  /// Set when the page closes itself because the app locked.
  bool _closedByLock = false;

  /// Set once changes are discarded, so leaving the page saves nothing.
  bool _discarded = false;

  /// Set while [_onBack] handles leaving (asking, saving, closing).
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _original = _note;
    _originalContent = widget.unlocked?.content ?? _original?.content ?? '';
    _key = widget.unlocked?.key;
    _titleController = TextEditingController(text: _original?.title ?? '');
    _contentController = TextEditingController(text: _originalContent);
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

  Note? get _note =>
      ref.read(notesProvider).where((n) => n.id == widget.noteId).firstOrNull;

  bool get _isLocked => _note?.isLocked ?? false;

  /// Stores the title and text as they are: encrypted if the note is locked.
  void _write({String? title, required String content}) {
    final notifier = ref.read(notesProvider.notifier);
    if (_isLocked) {
      notifier.updateLockedNote(
        widget.noteId,
        title: title,
        content: content,
        key: _key!,
      );
    } else {
      notifier.updateNote(widget.noteId, title: title, content: content);
    }
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
    _write(
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

    _write(title: title.isEmpty ? _untitled : title, content: content);
  }

  bool get _hasChanges =>
      _titleController.text != (_original?.title ?? '') ||
      _contentController.text != _originalContent;

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
        message: widget.isNew
            ? 'New notes are saved automatically. Discard deletes this note.'
            : 'Your changes are saved automatically. Discard puts the note '
                'back the way it was.',
      );
      if (!mounted || _closedByLock) return;
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
    _contentController.text = _originalContent;
    _autosaveTimer?.cancel(); // the text reset above scheduled one
  }

  /// Makes the current state the one Discard goes back to.
  void _markSaved() {
    _original = _note;
    _originalContent = _contentController.text;
  }

  /// ⋮ → Lock note: saves, then encrypts the content.
  Future<void> _lock() async {
    final key = await lockingKey(context, ref);
    if (key == null || !mounted) return;
    _key = key;
    _autosave();
    await ref.read(notesProvider.notifier).lockNote(widget.noteId, key);
    if (!mounted) return;
    setState(_markSaved);
  }

  /// ⋮ → Remove lock: saves, then stores the content unencrypted again.
  Future<void> _removeLock() async {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Remove lock?',
      message: 'The note will be stored unencrypted and open without the '
          'master password.',
      confirmLabel: 'Remove lock',
    );
    if (!confirmed || !mounted) return;
    _autosave();
    await ref.read(notesProvider.notifier).unlockNote(widget.noteId, _key!);
    if (!mounted) return;
    setState(_markSaved);
  }

  /// The app locked (L4) while a locked note is open: save it and close,
  /// together with anything open on top (e.g. a dialog).
  void _closeBecauseLocked() {
    if (_closedByLock) return;
    _closedByLock = true;
    _save();
    final route = ModalRoute.of(context);
    final navigator = Navigator.of(context);
    navigator.popUntil((r) => r == route);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    final locked = ref.watch(
      notesProvider.select(
        (notes) =>
            notes.where((n) => n.id == widget.noteId).firstOrNull?.isLocked ??
            false,
      ),
    );
    ref.listen(sessionProvider, (_, keys) {
      if (keys == null && _isLocked) _closeBecauseLocked();
    });

    return PopScope(
      // Back is handled by [_onBack] so it can ask before leaving.
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          // Popped by other means than back (e.g. the app navigating away):
          // keep whatever was typed.
          if (!_leaving && !_closedByLock) _save();
          return;
        }
        _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(locked ? 'Locked note' : 'Note'),
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
            PopupMenuButton<VoidCallback>(
              tooltip: 'More',
              onSelected: (action) => action(),
              itemBuilder: (_) => [
                if (locked)
                  PopupMenuItem(
                    value: _removeLock,
                    child: const ListTile(
                      leading: Icon(Icons.lock_open_outlined),
                      title: Text('Remove lock'),
                    ),
                  )
                else
                  PopupMenuItem(
                    value: _lock,
                    child: const ListTile(
                      leading: Icon(Icons.lock_outline),
                      title: Text('Lock note'),
                    ),
                  ),
              ],
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
