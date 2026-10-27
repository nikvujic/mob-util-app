import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/markdown.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/people_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/discard_scope.dart';
import 'package:the_app/widgets/format_bar.dart';
import 'package:the_app/widgets/markdown_text.dart';

/// A person's note, written on its own page (Round 109), as a recipe's
/// method is: Markdown, with the format bar; saved as it's typed. Done
/// keeps it; back asks, and Discard puts the note back as it was.
class PersonNotePage extends ConsumerStatefulWidget {
  final String personId;

  const PersonNotePage({super.key, required this.personId});

  @override
  ConsumerState<PersonNotePage> createState() => _PersonNotePageState();
}

class _PersonNotePageState extends ConsumerState<PersonNotePage> {
  late final PeopleNotifier _people = ref.read(peopleProvider.notifier);
  late final String _original =
      ref.read(peopleProvider).byId(widget.personId)?.note ?? '';
  late final MarkdownEditingController _note =
      MarkdownEditingController(text: _original);
  final _focus = FocusNode();

  bool _formatOpen = false;
  final _formatShown = ValueNotifier(false);
  late final _selectionControls = FormatBarSelectionControls(_formatShown);

  @override
  void initState() {
    super.initState();
    _note.addListener(_save);
    _focus.addListener(() {
      _note.editing = _focus.hasFocus;
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _note.dispose();
    _focus.dispose();
    _formatShown.dispose();
    super.dispose();
  }

  void _save() {
    final p = _people.byId(widget.personId);
    if (p == null || p.note == _note.text) return;
    _people.save(p.copyWith(note: _note.text));
    setState(() {});
  }

  void _format(MdEdit Function(String text, int start, int end) edit) {
    final selection = _note.selection;
    if (!selection.isValid) return;
    final result = edit(_note.text, selection.start, selection.end);
    _note.value = TextEditingValue(
      text: result.text,
      selection: TextSelection(
        baseOffset: result.start,
        extentOffset: result.end,
      ),
    );
  }

  late final List<FormatButton> _formatButtons = [
    FormatButton(Icons.format_list_numbered, 'Numbered list',
        () => _format((t, s, e) => toggleLines(t, s, e, MdLine.numbered))),
    FormatButton(Icons.format_list_bulleted, 'Bulleted list',
        () => _format((t, s, e) => toggleLines(t, s, e, MdLine.bullet))),
    FormatButton(Icons.checklist, 'Checkbox',
        () => _format((t, s, e) => toggleLines(t, s, e, MdLine.checkbox))),
    FormatButton(Icons.format_size, 'Heading', () => _format(cycleHeading)),
    FormatButton(Icons.format_bold, 'Bold',
        () => _format((t, s, e) => toggleWrap(t, s, e, '**'))),
    FormatButton(Icons.format_italic, 'Italic',
        () => _format((t, s, e) => toggleWrap(t, s, e, '*'))),
    FormatButton(Icons.border_color_outlined, 'Highlight',
        () => _format((t, s, e) => toggleWrap(t, s, e, '=='))),
    FormatButton(Icons.format_quote, 'Quote',
        () => _format((t, s, e) => toggleLines(t, s, e, MdLine.quote))),
  ];

  void _discard() {
    _note.removeListener(_save);
    final p = _people.byId(widget.personId);
    if (p != null) _people.save(p.copyWith(note: _original));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final name = ref.watch(
        peopleProvider.select((b) => b.byId(widget.personId)?.name ?? ''));
    final clearance = BottomActions.contentClearance +
        BottomActions.aboveClearance +
        (_formatOpen ? FormatBar.height + 8 : 0);
    return DiscardScope(
      changed: _note.text != _original,
      isNew: false,
      what: 'note',
      onDiscard: _discard,
      handleBack: () {
        if (!_focus.hasFocus) return false;
        FocusManager.instance.primaryFocus?.unfocus();
        return true;
      },
      child: Scaffold(
        appBar: AppBar(title: Text(name.isEmpty ? 'Note' : 'Note · $name')),
        body: ListView(
          key: const Key('personNotePage'),
          padding: EdgeInsets.fromLTRB(16, 12, 16, clearance),
          children: [
            CheckboxTaps(
              controller: _note,
              child: CheckboxBoxes(
                controller: _note,
                child: TextField(
                  key: const Key('personNoteField'),
                  controller: _note,
                  focusNode: _focus,
                  autofocus: _original.isEmpty,
                  selectionControls: _selectionControls,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  magnifierConfiguration: TextMagnifierConfiguration.disabled,
                  scrollPadding:
                      EdgeInsets.fromLTRB(20, 20, 20, clearance + 20),
                  inputFormatters: const [MarkdownListFormatter()],
                  style: TextStyle(color: colors.textPrimary, fontSize: 16),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'About them…',
                    hintStyle: TextStyle(color: colors.textHint),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ],
        ),
        floatingActionButton: BottomActions(
          above: [
            if (_focus.hasFocus)
              BottomAction(
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
          bar: _formatOpen && _focus.hasFocus
              ? FormatBar(buttons: _formatButtons)
              : null,
          actions: [
            BottomAction(
              icon: Icons.check,
              tooltip: 'Done',
              primary: true,
              // Done is a yes already: nothing asked.
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
