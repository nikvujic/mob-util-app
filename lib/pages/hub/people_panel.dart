import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/people.dart';
import 'package:the_app/pages/hub/recipe_page.dart' show showChoicesSheet;
import 'package:the_app/providers/people_provider.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/date_pick.dart';
import 'package:the_app/widgets/low_handles.dart';
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
  late final _note = TextEditingController(text: widget.person.note);

  PeopleNotifier get _people => ref.read(peopleProvider.notifier);
  bool get _kept => ref.read(peopleProvider).byId(_draft.id) != null;

  @override
  void didUpdateWidget(PersonPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.person.id != widget.person.id) {
      _editing = widget.startEditing;
      _draft = widget.person;
      _name.text = widget.person.name;
      _note.text = widget.person.note;
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _note.dispose();
    super.dispose();
  }

  void _toast(String message, {VoidCallback? undo}) =>
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text(message),
          action: undo == null
              ? null
              : SnackBarAction(label: 'Undo', onPressed: undo),
        ));

  /// The draft changed: kept once it has a name (spec: saved as you go).
  void _change(Person next) {
    setState(() => _draft = next);
    if (next.name.trim().isEmpty) return;
    _people.save(next.copyWith(name: next.name.trim()));
    // Saving may have tied a birthday to a date.
    final saved = ref.read(peopleProvider).byId(next.id);
    if (saved != null) {
      _draft = _draft.copyWith(dateId: () => saved.dateId);
    }
  }

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
    // The panel closes: what Undo needs is kept first.
    final people = _people;
    final messenger = ScaffoldMessenger.of(context);
    final removed = people.remove(_draft.id);
    widget.onClose();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$name deleted'),
        action: SnackBarAction(
            label: 'Undo', onPressed: () => people.undoRemove(removed)),
      ));
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

  /// Spec 6: a birthday already on the Dates page, taken over.
  Future<void> _birthdayFromDates() async {
    final free = _people.freeBirthdays();
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Birthdays in Dates',
                  style: TextStyle(color: context.colors.textSecondary)),
            ),
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
    if (why != null) _toast(why);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final book = ref.watch(peopleProvider);
    final now = ref.watch(clockProvider)();
    // As kept (after an Undo, say), unless being edited.
    final person = _editing ? _draft : (book.byId(_draft.id) ?? _draft);
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
          if (_editing)
            TextButton(
              key: const Key('personDone'),
              onPressed: _done,
              child: const Text('Done'),
            )
          else ...[
            IconButton(
              key: const Key('personEdit'),
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() {
                _draft = person;
                _name.text = person.name;
                _note.text = person.note;
                _editing = true;
              }),
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
    return Column(
      children: [
        header,
        Expanded(
          child: _editing
              ? _editFields(context, book, now)
              : _info(context, book, person, now),
        ),
      ],
    );
  }

  Widget _info(
      BuildContext context, PeopleBook book, Person person, DateTime now) {
    final colors = context.colors;
    final age = person.ageAt(now);
    final b = person.birthday, d = person.diedOn;
    final lines = <String>[
      if (b != null)
        'Born ${formatDayMonth(b.day, b.month, b.year)}'
            '${!person.deceased && age != null ? ' · $age' : ''}',
      if (person.deceased)
        d == null
            ? 'Deceased'
            : 'Died ${formatDayMonth(d.day, d.month, d.year)}'
                '${age == null ? '' : ' · lived to $age'}',
      '${person.gender.label}${person.highlighted ? ' · highlighted' : ''}',
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
        if (person.note.trim().isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text(person.note,
                key: const Key('personNote'),
                style: TextStyle(color: colors.textPrimary)),
          ),
        if (related.isNotEmpty) ...[
          const SizedBox(height: 8),
          for (final (r, other) in related)
            if (other != null)
              ListTile(
                key: Key('relation-${other.id}'),
                contentPadding: EdgeInsets.zero,
                dense: true,
                title: Text(other.name),
                subtitle: Text(relationName(r, person.id, other)),
                onTap: () => widget.onSelect(other.id),
              ),
        ],
      ],
    );
  }

  Widget _editFields(BuildContext context, PeopleBook book, DateTime now) {
    final colors = context.colors;
    final p = _draft;
    final b = p.birthday;
    final kept = book.byId(p.id) != null;
    final freeBirthdays = _people.freeBirthdays();
    return ListView(
      key: const Key('personForm'),
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        TextField(
          key: const Key('personName'),
          controller: _name,
          selectionControls: lowHandles,
          autofocus: !kept,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Full name'),
          onChanged: (v) => _change(_draft.copyWith(name: v)),
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 4),
        ListTile(
          key: const Key('personBirthday'),
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cake_outlined),
          title: Text(b == null
              ? 'Set birthday'
              : formatDayMonth(b.day, b.month, b.year)),
          subtitle: p.dateId == null
              ? null
              : Text('In Dates too', style: TextStyle(color: colors.textHint)),
          onTap: _pickBirthday,
          trailing: b == null
              ? null
              : IconButton(
                  key: const Key('clearBirthday'),
                  tooltip: 'No birthday',
                  icon: const Icon(Icons.close),
                  onPressed: () =>
                      _change(_draft.copyWith(birthday: () => null)),
                ),
        ),
        if (b == null && freeBirthdays.isNotEmpty)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('birthdayFromDates'),
              icon: const Icon(Icons.event_outlined),
              label: const Text('Birthday from Dates'),
              onPressed: _birthdayFromDates,
            ),
          ),
        if (b != null)
          SwitchListTile(
            key: const Key('personYearKnown'),
            contentPadding: EdgeInsets.zero,
            title: const Text('Year known'),
            value: b.year != null,
            // Known: picked with its year; unknown: the year let go.
            onChanged: (known) => known
                ? _pickBirthday()
                : _change(_draft.copyWith(
                    birthday: () => PersonDate(day: b.day, month: b.month),
                  )),
          ),
        SwitchListTile(
          key: const Key('personHighlighted'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Highlighted'),
          subtitle: Text('Stands out on the board',
              style: TextStyle(color: colors.textHint)),
          value: p.highlighted,
          onChanged: (v) => _change(_draft.copyWith(highlighted: v)),
        ),
        SwitchListTile(
          key: const Key('personDeceased'),
          contentPadding: EdgeInsets.zero,
          title: const Text('Deceased'),
          value: p.deceased,
          onChanged: (v) => _change(_draft.copyWith(deceased: v)),
        ),
        if (p.deceased)
          ListTile(
            key: const Key('personDiedOn'),
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.event_busy_outlined),
            title: Text(p.diedOn == null
                ? 'Set date of death'
                : formatDayMonth(
                    p.diedOn!.day, p.diedOn!.month, p.diedOn!.year)),
            onTap: _pickDeath,
          ),
        TextField(
          key: const Key('personNoteField'),
          controller: _note,
          selectionControls: lowHandles,
          minLines: 2,
          maxLines: 6,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(labelText: 'Note'),
          onChanged: (v) => _change(_draft.copyWith(note: v)),
        ),
        const SizedBox(height: 16),
        Text('RELATIONS',
            style: TextStyle(
                color: colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w600)),
        for (final r in book.of(p.id))
          if (book.byId(r.otherThan(p.id)) case final other?)
            ListTile(
              key: Key('editRelation-${r.id}'),
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: Text(other.name),
              subtitle: Text(relationName(r, p.id, other)),
              trailing: IconButton(
                tooltip: 'Remove relation',
                icon: const Icon(Icons.close),
                onPressed: () => _people.unrelate(r.id),
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
        if (kept) ...[
          const SizedBox(height: 16),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const Key('deletePerson'),
              style: TextButton.styleFrom(foregroundColor: colors.danger),
              icon: const Icon(Icons.delete_outline),
              label: const Text('Delete person'),
              onPressed: _delete,
            ),
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
