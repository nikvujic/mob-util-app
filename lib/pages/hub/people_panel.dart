import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/people.dart';
import 'package:the_app/pages/hub/person_note_page.dart';
import 'package:the_app/pages/hub/recipe_page.dart' show showChoicesSheet;
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/providers/people_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/date_pick.dart';
import 'package:the_app/widgets/low_handles.dart';
import 'package:the_app/widgets/markdown_text.dart';
import 'package:the_app/widgets/people_avatar.dart';
import 'package:the_app/widgets/text_input_sheet.dart';

/// What [relation] makes [other] to [me] ("Mother", "Son", "Partner",
/// "Kum"), for the panel's list.
String relationName(Relation relation, String me, Person? other) {
  final female = other?.gender == Gender.female;
  return switch (relation.kind) {
    RelationKind.parent when relation.to == me => female ? 'Mother' : 'Father',
    RelationKind.parent => female ? 'Daughter' : 'Son',
    RelationKind.partner when relation.former => 'Former partner',
    RelationKind.partner => 'Partner',
    RelationKind.sibling => female ? 'Sister' : 'Brother',
    RelationKind.other => relation.label.isEmpty ? 'Other' : relation.label,
  };
}

/// Brothers and sisters by a shared parent (worked out, not entered).
List<String> sharedParentSiblings(PeopleBook book, String id) => [
      for (final p in book.people)
        if (p.id != id &&
            book.parentsOf(p.id).any(book.parentsOf(id).contains) &&
            !book.relations.any((r) => r.involves(id) && r.involves(p.id)))
          p.id,
    ];

/// The selected person's panel (spec 3): their info, or (Edit) the
/// fields to change it, saved as they're changed.
class PersonPanel extends ConsumerStatefulWidget {
  /// The person as they are, or a new one not kept yet.
  final Person person;
  final bool startEditing;

  /// Another person picked from this one's relations.
  final ValueChanged<String> onSelect;

  /// Closed: Done on a new person with no name, Delete, or ×.
  final VoidCallback onClose;

  const PersonPanel({
    super.key,
    required this.person,
    required this.onSelect,
    required this.onClose,
    this.startEditing = false,
  });

  @override
  ConsumerState<PersonPanel> createState() => _PersonPanelState();
}

class _PersonPanelState extends ConsumerState<PersonPanel> {
  late bool _editing = widget.startEditing;
  late Person _draft = widget.person;
  late final _name = TextEditingController(text: widget.person.name);
  final _nameFocus = FocusNode();

  /// The note as shown (Markdown, read only); written on its own page.
  late final _noteView = MarkdownEditingController(text: widget.person.note);

  /// As it all was when Edit was pressed (Round 109): Discard goes back.
  PeopleBook? _bookBefore;
  DateBook? _datesBefore;

  /// Something changed since Edit was pressed.
  bool _dirty = false;

  /// The header's downward swipe so far (Round 109: down closes).
  double _swipe = 0;

  PeopleNotifier get _people => ref.read(peopleProvider.notifier);
  bool get _kept => ref.read(peopleProvider).byId(_draft.id) != null;

  @override
  void initState() {
    super.initState();
    if (_editing) _snapshot();
  }

  @override
  void didUpdateWidget(PersonPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.id != widget.person.id) {
      _editing = widget.startEditing;
      _draft = widget.person;
      _name.text = widget.person.name;
      if (_editing) _snapshot();
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _nameFocus.dispose();
    _noteView.dispose();
    super.dispose();
  }

  void _snapshot() {
    _bookBefore = ref.read(peopleProvider);
    _datesBefore = ref.read(datesProvider);
    _dirty = false;
  }

  void _toast(String message) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  /// The draft changed: kept once it has a name (spec: saved as you go).
  void _change(Person next) {
    setState(() {
      _draft = next;
      _dirty = true;
    });
    if (next.name.trim().isEmpty) return;
    _people.save(next.copyWith(name: next.name.trim()));
    // Saving may have tied a birthday to a date.
    final saved = ref.read(peopleProvider).byId(next.id);
    if (saved != null) {
      _draft = _draft.copyWith(dateId: () => saved.dateId);
    }
  }

  void _startEditing(Person person) => setState(() {
        _draft = person;
        _name.text = person.name;
        _editing = true;
        _snapshot();
      });

  /// Done: the changes kept, nothing asked (Round 109).
  void _done() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (!_kept) {
      widget.onClose();
      return;
    }
    // A name cleared isn't kept: the last one stays.
    final saved = ref.read(peopleProvider).byId(_draft.id)!;
    _name.text = saved.name;
    setState(() {
      _draft = saved;
      _editing = false;
    });
  }

  /// Everyone and the dates back as they were at Edit (the board's view
  /// stays); a new person gone again.
  void _discard() {
    FocusManager.instance.primaryFocus?.unfocus();
    final before = _bookBefore, dates = _datesBefore;
    if (before != null) {
      _people.replaceAll(before.copyWith(view: ref.read(peopleProvider).view));
    }
    if (dates != null) ref.read(datesProvider.notifier).replaceAll(dates);
    final saved = ref.read(peopleProvider).byId(_draft.id);
    if (saved == null) {
      widget.onClose();
      return;
    }
    _name.text = saved.name;
    setState(() {
      _draft = saved;
      _editing = false;
      _dirty = false;
    });
  }

  /// Back while editing (Round 109), as on other pages: unchanged, out
  /// of editing; changed, Save or Discard; a tap outside stays.
  Future<void> _back() async {
    // Out of the name field first.
    if (_nameFocus.hasFocus) {
      _nameFocus.unfocus();
      return;
    }
    if (!_dirty) {
      _done();
      return;
    }
    final isNew = _bookBefore?.byId(_draft.id) == null;
    final save = await showSaveChangesDialog(
      context,
      title: isNew ? 'Save new person?' : 'Save changes?',
      message: isNew
          ? 'New people are saved automatically. Discard deletes them.'
          : 'Your changes are saved automatically. Discard puts them back '
              'the way they were.',
    );
    if (!mounted || save == null) return;
    save ? _done() : _discard();
  }

  Future<void> _delete() async {
    final name = _draft.name.trim().isEmpty ? 'this person' : _draft.name;
    final ok = await showConfirmDialog(
      context,
      title: 'Delete $name?',
      message: 'Their relations go with them'
          '${_draft.dateId == null ? '' : ', and their birthday in Dates'}.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!ok || !mounted) return;
    // Round 109: asked already, so no Undo toast after.
    final people = _people;
    widget.onClose();
    people.remove(_draft.id);
  }

  Future<void> _pickBirthday() async {
    final today = ref.read(clockProvider)();
    final b = _draft.birthday;
    final picked = await pickDate(
      context,
      today: today,
      first: DateTime(1880),
      last: today,
      value: b == null ? null : DateTime(b.year ?? today.year, b.month, b.day),
      helpText: 'Birthday',
    );
    if (picked == null || !mounted) return;
    _change(_draft.copyWith(
      birthday: () =>
          PersonDate(day: picked.day, month: picked.month, year: picked.year),
    ));
  }

  /// Round 109: asked first; with it goes their date in Dates, and its
  /// reminders and note.
  Future<void> _clearBirthday() async {
    final ok = await showConfirmDialog(
      context,
      title: 'Remove birthday?',
      message: _draft.dateId == null
          ? null
          : 'Their birthday in Dates goes too, with its reminders and note.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok || !mounted) return;
    _change(_draft.copyWith(birthday: () => null));
  }

  /// Round 113: off, the birthday leaves Dates (asked first: its
  /// reminders and note there go with it); on, it's shown there again.
  Future<void> _setInDates(bool on) async {
    if (!on && _draft.dateId != null) {
      final ok = await showConfirmDialog(
        context,
        title: 'Remove from Dates?',
        message: 'Their birthday leaves the Dates page, with its reminders '
            'and note. It stays here.',
        confirmLabel: 'Remove',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    _change(_draft.copyWith(inDates: on));
  }

  /// Spec 6, Round 113: a birthday on the Dates page, its day copied (the
  /// original stays there).
  Future<void> _birthdayFromDates() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final free = _people.freeBirthdays();
    if (free.isEmpty) {
      _toast('No birthdays in Dates to take');
      return;
    }
    final picked = await showModalBottomSheet<String>(
      context: context,
      // Round 109: a long list scrolls.
      isScrollControlled: true,
      builder: (context) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Birthdays in Dates',
                    style: TextStyle(color: context.colors.textSecondary)),
              ),
              Flexible(
                child: ListView(
                  key: const Key('freeBirthdays'),
                  shrinkWrap: true,
                  children: [
                    for (final d in free)
                      ListTile(
                        key: Key('freeBirthday-${d.id}'),
                        leading: const Icon(Icons.cake_outlined),
                        title: Text(d.title),
                        subtitle: Text(formatDayMonth(d.day, d.month, d.year)),
                        onTap: () => Navigator.of(context).pop(d.id),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    // Taken over, it's theirs: kept now, with a name.
    if (_draft.name.trim().isEmpty) {
      _toast('Give them a name first');
      return;
    }
    _change(_draft);
    setState(() => _draft = _people.takeBirthday(_draft, picked));
  }

  Future<void> _pickDeath() async {
    final today = ref.read(clockProvider)();
    final d = _draft.diedOn;
    final picked = await pickDate(
      context,
      today: today,
      first: DateTime(1880),
      last: today,
      value: d == null ? null : DateTime(d.year ?? today.year, d.month, d.day),
      helpText: 'Date of death',
    );
    if (picked == null || !mounted) return;
    _change(_draft.copyWith(
      diedOn: () =>
          PersonDate(day: picked.day, month: picked.month, year: picked.year),
    ));
  }

  /// Spec 5.1: another person, then what they are to this one.
  Future<void> _addRelation() async {
    FocusManager.instance.primaryFocus?.unfocus();
    final book = ref.read(peopleProvider);
    final others = [
      for (final p in book.people)
        if (p.id != _draft.id &&
            !book.relations
                .any((r) => r.involves(p.id) && r.involves(_draft.id)))
          p,
    ];
    if (others.isEmpty) {
      _toast('Add another person first');
      return;
    }
    final otherId = await pickPerson(context, others, title: 'Related to');
    if (otherId == null || !mounted) return;
    final other = book.byId(otherId)!;
    final kind = await showChoicesSheet(context, other.name, const [
      (Icons.north, 'Their parent', 'parent'),
      (Icons.south, 'Their child', 'child'),
      (Icons.favorite_border, 'Partner', 'partner'),
      (Icons.heart_broken_outlined, 'Former partner', 'former'),
      (Icons.people_outline, 'Brother or sister', 'sibling'),
      (Icons.more_horiz, 'Other…', 'other'),
    ]);
    if (kind == null || !mounted) return;
    var label = '';
    if (kind == 'other') {
      final typed = await showTextInputSheet(context,
          hint: 'What they are (optional): Kum, friend…', submitLabel: 'Add');
      if (typed == null || !mounted) return;
      label = typed;
    }
    final me = _draft.id;
    final why = switch (kind) {
      'parent' =>
        _people.relate(RelationKind.parent, otherId, me, bring: otherId),
      'child' => _people.relate(RelationKind.parent, me, otherId),
      'partner' => _people.relate(RelationKind.partner, me, otherId),
      'former' =>
        _people.relate(RelationKind.partner, me, otherId, former: true),
      'sibling' => _people.relate(RelationKind.sibling, me, otherId),
      _ => _people.relate(RelationKind.other, me, otherId, label: label),
    };
    if (why != null) {
      _toast(why);
      return;
    }
    setState(() => _dirty = true);
    // Round 114: what followed from it, said.
    final also = [
      for (final id in _people.lastAlso)
        ref.read(peopleProvider).byId(id)?.name ?? '',
    ];
    if (also.isEmpty) return;
    _toast(kind == 'sibling'
        ? 'Their parents too: ${also.join(', ')}'
        : 'Their brothers and sisters too: ${also.join(', ')}');
  }

  Future<void> _editNote() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => PersonNotePage(personId: _draft.id),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final book = ref.watch(peopleProvider);
    final now = ref.watch(clockProvider)();
    // As kept (after an Undo, say), unless being edited.
    final person = _editing ? _draft : (book.byId(_draft.id) ?? _draft);
    if (_noteView.text != person.note) _noteView.text = person.note;
    final header = Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
      child: Row(
        children: [
          PeopleAvatar(
            age: person.ageGroupAt(now).index,
            female: person.gender == Gender.female,
            grey: person.deceased,
            size: 40,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _editing ? (_kept ? 'Edit person' : 'New person') : person.name,
              key: const Key('personPanelTitle'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  color: colors.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w600),
            ),
          ),
          if (_editing) ...[
            IconButton(
              key: const Key('personDiscard'),
              tooltip: 'Discard changes',
              icon: const Icon(Icons.settings_backup_restore),
              onPressed: _dirty ? _discard : null,
            ),
            TextButton(
              key: const Key('personDone'),
              onPressed: _done,
              child: const Text('Done'),
            ),
          ] else ...[
            IconButton(
              key: const Key('personEdit'),
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => _startEditing(person),
            ),
            IconButton(
              key: const Key('personClose'),
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: widget.onClose,
            ),
          ],
        ],
      ),
    );
    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _back();
      },
      child: Column(
        children: [
          // Round 109: swiped down (viewing), the panel closes.
          GestureDetector(
            key: const Key('personHeader'),
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: _editing ? null : (_) => _swipe = 0,
            onVerticalDragUpdate: _editing ? null : (d) => _swipe += d.delta.dy,
            onVerticalDragEnd: _editing
                ? null
                : (d) {
                    if (_swipe > 40 || d.primaryVelocity! > 300) {
                      widget.onClose();
                    }
                  },
            child: header,
          ),
          Expanded(
            child: _editing
                ? _editFields(context, book, now)
                : _info(context, book, person, now),
          ),
        ],
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Text(text,
            style: TextStyle(
                color: context.colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
      );

  Widget _info(
      BuildContext context, PeopleBook book, Person person, DateTime now) {
    final colors = context.colors;
    final age = person.ageAt(now);
    final b = person.birthday, d = person.diedOn;
    final hideNotes = ref.watch(preferencesProvider).hidePeopleNotes;
    final lines = <String>[
      if (b != null)
        'Born ${formatDayMonth(b.day, b.month, b.year)}'
            '${!person.deceased && age != null ? ' · $age' : ''}',
      if (person.deceased)
        d == null
            ? 'Deceased'
            : 'Died ${formatDayMonth(d.day, d.month, d.year)}'
                '${age == null ? '' : ' · lived to $age'}',
      [
        person.gender.label,
        if (book.mainId == person.id) 'main person',
        if (person.highlighted) 'highlighted',
      ].join(' · '),
    ];
    final related = [
      for (final r in book.of(person.id))
        (r, book.byId(r.otherThan(person.id))),
      for (final s in sharedParentSiblings(book, person.id))
        (
          Relation(id: '', kind: RelationKind.sibling, from: person.id, to: s),
          book.byId(s),
        ),
    ];
    return ListView(
      key: const Key('personInfo'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      children: [
        for (final line in lines)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(line, style: TextStyle(color: colors.textSecondary)),
          ),
        if (related.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final (r, other) in related)
            if (other != null)
              ListTile(
                key: Key('relation-${other.id}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: _smallAvatar(other, now),
                title: Text(other.name),
                subtitle: Text(relationName(r, person.id, other)),
                onTap: () => widget.onSelect(other.id),
              ),
        ],
        // Round 109: the note last, as Markdown; written on its own page.
        if (!hideNotes && _kept) ...[
          Row(
            children: [
              Expanded(child: _sectionTitle('NOTE')),
              IconButton(
                key: const Key('personNoteEdit'),
                tooltip: 'Edit note',
                icon: const Icon(Icons.edit_note),
                onPressed: _editNote,
              ),
            ],
          ),
          if (person.note.trim().isEmpty)
            Text('Nothing written yet',
                style: TextStyle(color: colors.textMuted))
          else
            CheckboxBoxes(
              controller: _noteView,
              child: TextField(
                key: const Key('personNote'),
                selectionControls: lowHandles,
                controller: _noteView,
                readOnly: true,
                showCursor: false,
                enableInteractiveSelection: false,
                maxLines: null,
                style: TextStyle(color: colors.textPrimary, fontSize: 15),
                decoration: const InputDecoration(
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.zero,
                  isDense: true,
                ),
              ),
            ),
        ],
        const SizedBox(key: Key('personInfoEnd'), height: 1),
      ],
    );
  }

  Widget _smallAvatar(Person p, DateTime now) => PeopleAvatar(
        age: p.ageGroupAt(now).index,
        female: p.gender == Gender.female,
        grey: p.deceased,
        size: 32,
      );

  Widget _editFields(BuildContext context, PeopleBook book, DateTime now) {
    final colors = context.colors;
    final p = _draft;
    final b = p.birthday;
    final kept = book.byId(p.id) != null;
    final freeBirthdays = _people.freeBirthdays();
    // Round 109: every row's text in one column, behind an icon.
    const pad = EdgeInsets.zero;
    return ListView(
      key: const Key('personForm'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        SegmentedButton<Gender>(
          key: const Key('personGender'),
          segments: [
            for (final g in Gender.values)
              ButtonSegment(value: g, label: Text(g.label)),
          ],
          selected: {p.gender},
          showSelectedIcon: false,
          onSelectionChanged: (s) => _change(_draft.copyWith(gender: s.first)),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('personName'),
          controller: _name,
          focusNode: _nameFocus,
          selectionControls: lowHandles,
          autofocus: !kept,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Full name'),
          onChanged: (v) => _change(_draft.copyWith(name: v)),
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Expanded(
              child: ListTile(
                key: const Key('personBirthday'),
                contentPadding: pad,
                leading: const Icon(Icons.cake_outlined),
                title: Text(b == null
                    ? 'Set birthday'
                    : formatDayMonth(b.day, b.month, b.year)),
                subtitle: p.dateId == null
                    ? null
                    : Text('In Dates too',
                        style: TextStyle(color: colors.textHint)),
                onTap: _pickBirthday,
              ),
            ),
            if (b != null)
              IconButton(
                key: const Key('clearBirthday'),
                tooltip: 'Remove birthday',
                icon: const Icon(Icons.close),
                onPressed: _clearBirthday,
              )
            else if (freeBirthdays.isNotEmpty)
              OutlinedButton.icon(
                key: const Key('birthdayFromDates'),
                icon: const Icon(Icons.event_outlined, size: 18),
                label: const Text('From Dates'),
                onPressed: _birthdayFromDates,
              ),
          ],
        ),
        if (b != null)
          SwitchListTile(
            key: const Key('personYearKnown'),
            contentPadding: pad,
            secondary: const Icon(Icons.event_available_outlined),
            title: const Text('Year known'),
            value: b.year != null,
            // Known: picked with its year; unknown: the year let go.
            onChanged: (known) => known
                ? _pickBirthday()
                : _change(_draft.copyWith(
                    birthday: () => PersonDate(day: b.day, month: b.month),
                  )),
          ),
        // Round 113: their birthday shown in Dates (its overview and
        // reminders), or kept to People.
        if (b != null)
          SwitchListTile(
            key: const Key('personInDates'),
            contentPadding: pad,
            secondary: const Icon(Icons.event_note_outlined),
            title: const Text('Show in Dates'),
            subtitle: Text('With its reminders',
                style: TextStyle(color: colors.textHint)),
            value: p.inDates,
            onChanged: _setInDates,
          ),
        SwitchListTile(
          key: const Key('personDeceased'),
          contentPadding: pad,
          secondary: const Icon(Icons.local_florist_outlined),
          title: const Text('Deceased'),
          value: p.deceased,
          onChanged: (v) => _change(_draft.copyWith(deceased: v)),
        ),
        if (p.deceased)
          ListTile(
            key: const Key('personDiedOn'),
            contentPadding: pad,
            leading: const Icon(Icons.event_busy_outlined),
            title: Text(p.diedOn == null
                ? 'Set date of death'
                : formatDayMonth(
                    p.diedOn!.day, p.diedOn!.month, p.diedOn!.year)),
            onTap: _pickDeath,
          ),
        _sectionTitle('RELATIONS'),
        for (final r in book.of(p.id))
          if (book.byId(r.otherThan(p.id)) case final other?)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.background,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: colors.divider),
                ),
                child: ListTile(
                  key: Key('editRelation-${r.id}'),
                  contentPadding: const EdgeInsets.only(left: 10, right: 2),
                  dense: true,
                  leading: _smallAvatar(other, now),
                  title: Text(other.name,
                      style: TextStyle(color: colors.textPrimary)),
                  subtitle: Text(relationName(r, p.id, other)),
                  trailing: IconButton(
                    tooltip: 'Remove relation',
                    icon: const Icon(Icons.close),
                    onPressed: () {
                      _people.unrelate(r.id);
                      setState(() => _dirty = true);
                    },
                  ),
                ),
              ),
            ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            key: const Key('addRelation'),
            icon: const Icon(Icons.add_link),
            label: const Text('Add relation'),
            onPressed: kept ? _addRelation : null,
          ),
        ),
        if (!kept)
          Text('Give them a name to add relations.',
              style: TextStyle(color: colors.textHint, fontSize: 13)),
        const SizedBox(height: 8),
        SwitchListTile(
          key: const Key('personHighlighted'),
          contentPadding: pad,
          secondary: const Icon(Icons.star_outline),
          title: const Text('Highlighted'),
          subtitle: Text('Stands out on the board',
              style: TextStyle(color: colors.textHint)),
          value: p.highlighted,
          onChanged: (v) => _change(_draft.copyWith(highlighted: v)),
        ),
        SwitchListTile(
          key: const Key('personMain'),
          contentPadding: pad,
          secondary: const Icon(Icons.center_focus_strong_outlined),
          title: const Text('Main person'),
          subtitle: Text(
              'The board opens on them; their family can be '
              'highlighted',
              style: TextStyle(color: colors.textHint)),
          value: book.mainId == p.id,
          onChanged: kept
              ? (v) {
                  _people.setMain(v ? p.id : null);
                  setState(() => _dirty = true);
                }
              : null,
        ),
        if (kept) ...[
          const SizedBox(height: 16),
          OutlinedButton.icon(
            key: const Key('deletePerson'),
            style: OutlinedButton.styleFrom(
              foregroundColor: colors.danger,
              side: BorderSide(color: colors.danger),
              minimumSize: const Size.fromHeight(44),
            ),
            icon: const Icon(Icons.delete_outline),
            label: const Text('Delete person'),
            onPressed: _delete,
          ),
        ],
      ],
    );
  }
}

/// Someone from [people], searched by name (Find, Add relation).
Future<String?> pickPerson(
  BuildContext context,
  List<Person> people, {
  required String title,
}) =>
    showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _PersonPicker(people: people, title: title),
    );

class _PersonPicker extends StatefulWidget {
  final List<Person> people;
  final String title;

  const _PersonPicker({required this.people, required this.title});

  @override
  State<_PersonPicker> createState() => _PersonPickerState();
}

class _PersonPickerState extends State<_PersonPicker> {
  var _query = '';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final q = _query.trim().toLowerCase();
    final shown = [
      for (final p in widget.people)
        if (q.isEmpty || p.name.toLowerCase().contains(q)) p,
    ]..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.sizeOf(context).height * 0.6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(widget.title,
                    style: TextStyle(color: colors.textSecondary)),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  reverse: true,
                  children: [
                    for (final p in shown.reversed)
                      ListTile(
                        key: Key('pickPerson-${p.id}'),
                        title: Text(p.name),
                        onTap: () => Navigator.of(context).pop(p.id),
                      ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                child: TextField(
                  key: const Key('pickPersonSearch'),
                  selectionControls: lowHandles,
                  decoration: const InputDecoration(
                    hintText: 'Search by name',
                    prefixIcon: Icon(Icons.search),
                  ),
                  onChanged: (v) => setState(() => _query = v),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
