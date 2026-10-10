import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/pages/notes/note_history.dart';
import 'package:the_app/pages/notes/note_keys.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/line_numbers.dart';
import 'package:the_app/widgets/markdown_text.dart';
import 'package:the_app/widgets/text_input_sheet.dart';

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
/// editing an existing note, Discard changes restores that version without
/// leaving the page. ↶ / ↷ undo and redo edits step by step (N8).
///
/// A locked note (N6) is opened with its content already decrypted
/// ([unlocked]); edits are saved encrypted with the same key. If the app
/// locks while it's open (L4), the note is saved and closed. Locking and
/// removing the lock (bottom button) take effect at once and count as saving:
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
  late final MarkdownEditingController _contentController;
  final FocusNode _contentFocusNode = FocusNode();
  final _contentScroll = ScrollController();

  /// The text field, for the line numbers (N12) to follow.
  final _contentFieldKey = GlobalKey();
  late final AppLifecycleListener _lifecycleListener;
  Timer? _autosaveTimer;

  /// Undo / redo (N8).
  late final NoteHistory _history;

  /// Set while the history itself changes the text (undo, redo, discard).
  bool _applying = false;

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
    // Markdown basics styled as they're typed (N9).
    _contentController = MarkdownEditingController(text: _originalContent);
    // Markdown symbols show only on the line being edited (N9).
    _contentFocusNode.addListener(
      () => _contentController.editing = _contentFocusNode.hasFocus,
    );
    _history = NoteHistory(_text, clock: ref.read(clockProvider));
    _titleController.addListener(_onEdit);
    _contentController.addListener(_onEdit);
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
    _contentScroll.dispose();
    _history.dispose();
    super.dispose();
  }

  NoteText get _text =>
      (title: _titleController.value, content: _contentController.value);

  void _onEdit() {
    if (!_applying) _history.changed(_text);
  }

  /// Shows [text] in the fields (from undo, redo or discard); saved like
  /// any edit.
  void _apply(NoteText text) {
    _applying = true;
    _titleController.value = text.title;
    _contentController.value = text.content;
    _applying = false;
  }

  void _undo() {
    final text = _history.undo();
    if (text != null) _apply(text);
  }

  void _redo() {
    final text = _history.redo();
    if (text != null) _apply(text);
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
    _apply((
      title: TextEditingValue(text: original.title),
      content: TextEditingValue(text: _originalContent),
    ));
    _autosaveTimer?.cancel(); // the text reset above scheduled one
    _history.changed(_text, separate: true); // ↶ brings the edits back
  }

  /// Makes the current state the one Discard goes back to.
  void _markSaved() {
    _original = _note;
    _originalContent = _contentController.text;
  }

  /// Edit title: the title field is out of thumb reach (N11).
  Future<void> _editTitle() async {
    final title = await showTextInputSheet(
      context,
      hint: 'Title',
      initialValue: _titleController.text,
    );
    if (title != null && mounted) _titleController.text = title;
  }

  /// Lock note: saves, then encrypts the content.
  Future<void> _lock() async {
    final key = await lockingKey(context, ref);
    if (key == null || !mounted) return;
    _key = key;
    _autosave();
    await ref.read(notesProvider.notifier).lockNote(widget.noteId, key);
    if (!mounted) return;
    setState(_markSaved);
  }

  /// Remove lock: saves, then stores the content unencrypted again.
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
    final route = ModalRoute.of(context);
    // Already closed (e.g. the whole section locked and closed it).
    if (_closedByLock || !(route?.isActive ?? false)) return;
    _closedByLock = true;
    _save();
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
    final lineNumbers =
        ref.watch(preferencesProvider.select((p) => p.noteLineNumbers));
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
        ),
        // Actions at the bottom, on the side of the hand that opened the
        // note (G11).
        floatingActionButton: ListenableBuilder(
          listenable: Listenable.merge(
            [_titleController, _contentController, _history],
          ),
          builder: (context, _) => BottomActions(
            // ↶ ↷ read left to right on either side.
            keepOrderOfLast: 2,
            // Up at the top, the title is out of thumb reach (N11).
            above: BottomAction(
              icon: Icons.title,
              tooltip: 'Edit title',
              onPressed: _editTitle,
            ),
            actions: [
              locked
                  ? BottomAction(
                      icon: Icons.lock_open_outlined,
                      tooltip: 'Remove lock',
                      onPressed: _removeLock,
                    )
                  : BottomAction(
                      icon: Icons.lock_outline,
                      tooltip: 'Lock note',
                      onPressed: _lock,
                    ),
              if (!widget.isNew && _hasChanges)
                BottomAction(
                  // Not ↶: that's undo.
                  icon: Icons.settings_backup_restore,
                  tooltip: 'Discard changes',
                  onPressed: _revertInPlace,
                ),
              // Outermost, under the thumb.
              BottomAction(
                icon: Icons.undo,
                tooltip: 'Undo',
                enabled: _history.canUndo,
                onPressed: _undo,
              ),
              BottomAction(
                icon: Icons.redo,
                tooltip: 'Redo',
                enabled: _history.canRedo,
                onPressed: _redo,
              ),
            ],
          ),
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
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  color: context.colors.textPrimary,
                ),
                decoration: InputDecoration(
                  border: InputBorder.none,
                  hintText: 'Title',
                  hintStyle: TextStyle(color: context.colors.textHint),
                ),
              ),
            ),
            Divider(height: 1, color: context.colors.divider),
            Expanded(
              child: Padding(
                padding: EdgeInsets.fromLTRB(lineNumbers ? 6 : 16, 8, 16, 16),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Like a code editor (N12).
                    if (lineNumbers)
                      LineNumbers(
                        controller: _contentController,
                        scroll: _contentScroll,
                        field: _contentFieldKey,
                      ),
                    Expanded(
                      child: KeyedSubtree(
                        key: _contentFieldKey,
                        child: TextField(
                          key: const Key('noteContentField'),
                          controller: _contentController,
                          focusNode: _contentFocusNode,
                          scrollController: _contentScroll,
                          autofocus: widget.isNew,
                          keyboardType: TextInputType.multiline,
                          textCapitalization: TextCapitalization.sentences,
                          maxLines: null,
                          expands: true,
                          // Enter continues a list (N9).
                          inputFormatters: const [MarkdownListFormatter()],
                          textAlignVertical: TextAlignVertical.top,
                          style: TextStyle(
                            color: context.colors.textPrimary,
                            fontSize: 16,
                          ),
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Start writing…',
                            hintStyle:
                                TextStyle(color: context.colors.textHint),
                            // The text ends above the buttons, never behind them.
                            contentPadding: EdgeInsets.only(
                              bottom: BottomActions.contentClearance +
                                  BottomActions.aboveClearance,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
