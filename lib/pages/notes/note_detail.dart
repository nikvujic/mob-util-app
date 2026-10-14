import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/crypto.dart';
import 'package:the_app/core/markdown.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/note.dart';
import 'package:the_app/pages/notes/note_history.dart';
import 'package:the_app/pages/notes/note_keys.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/session_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/format_bar.dart';
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
  final FocusNode _titleFocusNode = FocusNode();

  /// The keyboard's height when last built: it closing while editing goes
  /// back to viewing (N13).
  double _keyboard = 0;

  /// Editing (a field has focus) rather than viewing (N13).
  bool get _editing => _contentFocusNode.hasFocus || _titleFocusNode.hasFocus;

  /// Back to viewing: no keyboard, Markdown symbols hidden.
  void _stopEditing() {
    _contentFocusNode.unfocus();
    _titleFocusNode.unfocus();
  }

  final _contentScroll = ScrollController();

  /// Room below the text, so its end can scroll clear of the buttons (and
  /// of the format bar, while it's open).
  double get _clearance =>
      BottomActions.contentClearance +
      BottomActions.aboveClearance +
      (_formatOpen ? FormatBar.height + 8 : 0);

  /// The format bar (N17) is open.
  bool _formatOpen = false;

  /// While it is, the cursor's handle isn't shown (Round 29).
  final _formatShown = ValueNotifier(false);
  late final _selectionControls = FormatBarSelectionControls(_formatShown);

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
    _formatShown.dispose();
    _titleFocusNode.dispose();
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

  /// A format button's edit (N17) on the selection (or the cursor).
  void _format(MdEdit Function(String text, int start, int end) edit) {
    final content = _contentController;
    final selection = content.selection;
    if (!selection.isValid) return;
    final result = edit(content.text, selection.start, selection.end);
    content.value = TextEditingValue(
      text: result.text,
      selection: TextSelection(
        baseOffset: result.start,
        extentOffset: result.end,
      ),
    );
  }

  /// The format bar's buttons (N17, Round 27), most used first.
  late final List<FormatButton> _formatButtons = [
    FormatButton(Icons.checklist, 'Checkbox',
        () => _format((t, s, e) => toggleLines(t, s, e, MdLine.checkbox))),
    FormatButton(Icons.format_list_bulleted, 'Bulleted list',
        () => _format((t, s, e) => toggleLines(t, s, e, MdLine.bullet))),
    FormatButton(Icons.format_list_numbered, 'Numbered list',
        () => _format((t, s, e) => toggleLines(t, s, e, MdLine.numbered))),
    FormatButton(Icons.format_size, 'Heading', () => _format(cycleHeading)),
    FormatButton(Icons.format_bold, 'Bold',
        () => _format((t, s, e) => toggleWrap(t, s, e, '**'))),
    FormatButton(Icons.format_italic, 'Italic',
        () => _format((t, s, e) => toggleWrap(t, s, e, '*'))),
    // Round 39: multi-line code blocks up front, in view without scrolling
    // the bar; Strikethrough's button went to make room (unused; ~~ still
    // shows struck through).
    FormatButton(
        Icons.data_object, 'Code block', () => _format(toggleCodeBlock)),
    FormatButton(Icons.code, 'Code',
        () => _format((t, s, e) => toggleWrap(t, s, e, '`'))),
    FormatButton(Icons.border_color_outlined, 'Highlight',
        () => _format((t, s, e) => toggleWrap(t, s, e, '=='))),
    FormatButton(Icons.format_quote, 'Quote',
        () => _format((t, s, e) => toggleLines(t, s, e, MdLine.quote))),
    FormatButton(Icons.horizontal_rule, 'Divider',
        () => _format((t, s, e) => insertDivider(t, e))),
  ];

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

  /// A note with no title ("Untitled" counts as none) and nothing but
  /// spaces and new lines in it: removed on leaving (N14).
  static bool _isEmpty(String title, String content) {
    final t = title.trim();
    return (t.isEmpty || t == NotesNotifier.defaultTitle) &&
        content.trim().isEmpty;
  }

  /// Saves on leaving; an empty note, new or not, is removed instead
  /// (N14).
  void _save() {
    _autosaveTimer?.cancel();
    if (_discarded) return;
    final title = _titleController.text.trim();
    final content = _contentController.text;
    if (_isEmpty(title, content)) {
      ref.read(notesProvider.notifier).removeNotes({widget.noteId});
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
    if (widget.isNew ||
        original == null ||
        _isEmpty(original.title, _originalContent)) {
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
      if (save == null) {
        _leaving = false; // tapped outside: stay and keep editing
        return;
      }
      if (save) {
        _save();
      } else {
        _discardAll();
      }
    } else {
      _save(); // removes an empty note
    }
    // A section lock can close everything above the home screen while the
    // dialog is open (taking this page with it): then there's nothing left
    // to pop here, and popping would remove the home screen.
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).pop();
    }
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
  /// The title changes as it's typed, and may be left empty (saved as
  /// "Untitled" on leaving, like clearing it at the top).
  /// A default title ("New Note", "Untitled") comes selected, so typing
  /// replaces it (Round 27).
  Future<void> _editTitle() {
    final title = _titleController.text;
    final placeholder =
        title.trim() == NotesNotifier.defaultTitle || title.trim() == _untitled;
    _titleController.selection = placeholder
        ? TextSelection(baseOffset: 0, extentOffset: title.length)
        : TextSelection.collapsed(offset: title.length);
    return showTextInputSheet(
      context,
      hint: 'Title',
      submitLabel: 'Done',
      controller: _titleController,
    );
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
    // The keyboard closed (its back key) while editing: back to viewing.
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboard == 0 && _keyboard > 0 && _editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && MediaQuery.viewInsetsOf(context).bottom == 0) {
          _stopEditing();
        }
      });
    }
    _keyboard = keyboard;
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
        // Editing: back goes to viewing first (N13).
        if (_editing) {
          _stopEditing();
          return;
        }
        _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          // The arrow always leaves (asking to save if changed); only the
          // system back steps out of editing first (N13).
          leading: BackButton(onPressed: _onBack),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('Note'),
              if (locked)
                const Padding(
                  padding: EdgeInsets.only(left: 6),
                  child: Icon(
                    Icons.lock_outline,
                    size: 18,
                    semanticLabel: 'Locked',
                  ),
                ),
            ],
          ),
        ),
        // Actions at the bottom, on the side of the hand that opened the
        // note (G11).
        floatingActionButton: ListenableBuilder(
          listenable: Listenable.merge(
            [_titleController, _contentController, _history, _contentFocusNode],
          ),
          builder: (context, _) => BottomActions(
            // ↶ ↷ read left to right on either side.
            keepOrderOfLast: 2,
            // Up at the top, the title is out of thumb reach (N11).
            above: [
              BottomAction(
                icon: Icons.title,
                tooltip: 'Edit title',
                onPressed: _editTitle,
              ),
              // Only while typing the text, keyboard up: opens the format
              // bar (N17; it took the Checkbox button's place, Round 27).
              if (_contentFocusNode.hasFocus)
                BottomAction(
                  // "Tt" (Round 29: not the underlined A).
                  icon: _formatOpen
                      ? Icons.keyboard_hide_outlined
                      : Icons.text_fields,
                  tooltip: _formatOpen ? 'Close formatting' : 'Format',
                  onPressed: () {
                    setState(() => _formatOpen = !_formatOpen);
                    _formatShown.value = _formatOpen;
                  },
                ),
            ],
            bar: _formatOpen && _contentFocusNode.hasFocus
                ? FormatBar(buttons: _formatButtons)
                : null,
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
              // Always there, greyed out until there's something to
              // discard, so the buttons don't shift (Round 20).
              BottomAction(
                // Not ↶: that's undo.
                icon: Icons.settings_backup_restore,
                tooltip: 'Discard changes',
                enabled: !widget.isNew && _hasChanges,
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
                magnifierConfiguration: TextMagnifierConfiguration.disabled,
                controller: _titleController,
                focusNode: _titleFocusNode,
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
                      // The text scrolls with room below it, so its end can
                      // rise above the buttons; nothing covers it, and taps
                      // between the buttons reach it (Round 15: padding
                      // inside the field hid the lines under it).
                      child: LayoutBuilder(
                        builder: (context, box) => SingleChildScrollView(
                          key: const Key('noteContentScroll'),
                          controller: _contentScroll,
                          padding: EdgeInsets.only(bottom: _clearance),
                          child: ConstrainedBox(
                            // At least the page tall: a tap anywhere below
                            // short text still starts typing.
                            constraints:
                                BoxConstraints(minHeight: box.maxHeight),
                            child: KeyedSubtree(
                              key: _contentFieldKey,
                              // Tapping a checkbox ticks it (N15).
                              child: CheckboxTaps(
                                controller: _contentController,
                                child: CheckboxBoxes(
                                  controller: _contentController,
                                  child: TextField(
                                    key: const Key('noteContentField'),
                                    controller: _contentController,
                                    selectionControls: _selectionControls,
                                    focusNode: _contentFocusNode,
                                    autofocus: widget.isNew,
                                    keyboardType: TextInputType.multiline,
                                    textCapitalization:
                                        TextCapitalization.sentences,
                                    maxLines: null,
                                    // No magnifier while selecting (Round 15).
                                    magnifierConfiguration:
                                        TextMagnifierConfiguration.disabled,
                                    // The line typed on stays above the
                                    // buttons.
                                    scrollPadding: EdgeInsets.fromLTRB(
                                        20, 20, 20, _clearance + 20),
                                    // Enter continues a list (N9).
                                    inputFormatters: const [
                                      MarkdownListFormatter(),
                                    ],
                                    style: TextStyle(
                                      color: context.colors.textPrimary,
                                      fontSize: 16,
                                    ),
                                    decoration: InputDecoration(
                                      border: InputBorder.none,
                                      hintText: 'Start writing…',
                                      hintStyle: TextStyle(
                                        color: context.colors.textHint,
                                      ),
                                      contentPadding: EdgeInsets.zero,
                                    ),
                                  ),
                                ),
                              ),
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
