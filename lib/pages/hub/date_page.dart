import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/id.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/pages/hub/date_reminder_sheet.dart';
import 'package:the_app/pages/hub/dates.dart';
import 'package:the_app/providers/dates_alerts_provider.dart';
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// A date (Round 57): its title, type, day (and year), every year or
/// once, a note and up to three reminders. Saved as it's changed, once
/// it has a title; a new one left without one is dropped. Delete is at
/// the end, with Undo.
class DatePage extends ConsumerStatefulWidget {
  /// The date to open, or null for a new one on [on].
  final String? dateId;
  final DateTime? on;

  const DatePage({super.key, this.dateId, this.on});

  @override
  ConsumerState<DatePage> createState() => _DatePageState();
}

class _DatePageState extends ConsumerState<DatePage> {
  late DateEntry _draft = ref.read(datesProvider).byId(widget.dateId ?? '') ??
      DateEntry(
        id: generateId(),
        title: '',
        type: DateType.birthday,
        day: (widget.on ?? DateTime.now()).day,
        month: (widget.on ?? DateTime.now()).month,
        year: (widget.on ?? DateTime.now()).year,
      );

  late final _title = TextEditingController(text: _draft.title);
  late final _note = TextEditingController(text: _draft.note);

  DatesNotifier get _notifier => ref.read(datesProvider.notifier);

  DateTime get _today => dayOf(ref.read(clockProvider)());

  @override
  void dispose() {
    _title.dispose();
    _note.dispose();
    super.dispose();
  }

  /// [date] as it is now: kept, and saved once it has a title.
  void _change(DateEntry date) {
    setState(() => _draft = date);
    if (date.title.trim().isNotEmpty) _notifier.save(date);
  }

  Future<void> _pickDate() async {
    final today = _today;
    final d = _draft;
    final shownYear = d.year ?? today.year;
    final last = DateTime(shownYear, d.month + 1, 0).day;
    final picked = await showDatePicker(
      context: context,
      initialDate: DateTime(shownYear, d.month, d.day > last ? last : d.day),
      firstDate: DateTime(1900),
      lastDate: DateTime(today.year + 50, 12, 31),
    );
    if (picked == null || !mounted) return;
    _change(_draft.copyWith(
      day: picked.day,
      month: picked.month,
      // A year not known stays so (every year only).
      year: () => _draft.year == null && _draft.yearly ? null : picked.year,
    ));
  }

  Future<void> _editReminder(int? index) async {
    final reminders = [..._draft.reminders];
    final start = index == null ? DateReminder.standard : reminders[index];
    final picked = await showModalBottomSheet<DateReminder>(
      context: context,
      isScrollControlled: true,
      builder: (_) => ReminderSheet(start: start),
    );
    if (picked == null || !mounted) return;
    if (index == null) {
      reminders.add(picked);
    } else {
      reminders[index] = picked;
    }
    _change(_draft.copyWith(reminders: reminders));
  }

  void _delete() {
    final date = _draft;
    final notifier = _notifier;
    final before = notifier.delete(date.id);
    final messenger = ScaffoldMessenger.of(context);
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('${date.title} deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.replaceAll(before),
        ),
      ));
  }

  Widget _heading(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: Text(
          text,
          style: TextStyle(
            color: context.colors.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    // Kept in step with the book (an Undo elsewhere, a restore).
    final saved = ref.watch(datesProvider).byId(_draft.id) != null;
    final date = _draft;
    final colors = context.colors;
    final today = _today;
    final next = date.nextFrom(today);
    final years = next == null ? null : yearsLabel(date, next);
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.dateId == null && !saved ? 'New date' : 'Date'),
      ),
      body: PullDownList.children(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: TextField(
              key: const Key('dateTitle'),
              controller: _title,
              autofocus: widget.dateId == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Title'),
              onChanged: (text) => _change(_draft.copyWith(title: text)),
            ),
          ),
          _heading('TYPE'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final type in DateType.values)
                  ChoiceChip(
                    key: Key('dateType-${type.name}'),
                    avatar: Icon(type.icon, size: 18, color: type.colour),
                    label: Text(type.label),
                    selected: date.type == type,
                    // A type sets every year or once (it can be changed
                    // after); once needs a year.
                    onSelected: (_) => _change(date.copyWith(
                      type: type,
                      yearly: type.yearly,
                      year: () =>
                          date.year ?? (type.yearly ? null : today.year),
                    )),
                  ),
              ],
            ),
          ),
          _heading('WHEN'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: ActionChip(
                key: const Key('dateDay'),
                avatar: const Icon(Icons.calendar_today, size: 18),
                label: Text(formatDayMonth(date.day, date.month, date.year)),
                onPressed: _pickDate,
              ),
            ),
          ),
          if (next != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 0),
              child: Text(
                key: const Key('dateNext'),
                [
                  formatDay(next, today: today),
                  howSoon(next, today),
                  if (years != null) years,
                ].join('  ·  '),
                style: TextStyle(color: colors.textMuted, fontSize: 12),
              ),
            ),
          SwitchListTile(
            key: const Key('dateYearly'),
            title: const Text('Every year'),
            value: date.yearly,
            onChanged: (on) => _change(date.copyWith(
              yearly: on,
              year: () => on ? date.year : (date.year ?? today.year),
            )),
          ),
          if (date.yearly)
            SwitchListTile(
              key: const Key('dateYearKnown'),
              title: const Text('Year known'),
              subtitle: const Text('For the age, or how many years'),
              value: date.year != null,
              onChanged: (on) =>
                  _change(date.copyWith(year: () => on ? today.year : null)),
            ),
          _heading('REMINDERS'),
          for (final (i, r) in date.reminders.indexed)
            ListTile(
              key: Key('dateReminder-$i'),
              leading: const Icon(Icons.notifications_outlined),
              title: Text(reminderLabel(r)),
              onTap: () => _editReminder(i),
              trailing: IconButton(
                key: Key('dateReminderRemove-$i'),
                tooltip: 'Remove reminder',
                icon: const Icon(Icons.close),
                onPressed: () => _change(date.copyWith(reminders: [
                  for (final (j, other) in date.reminders.indexed)
                    if (j != i) other,
                ])),
              ),
            ),
          if (date.reminders.length < DateReminder.most)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('dateAddReminder'),
                  icon: const Icon(Icons.add),
                  label: const Text('Add a reminder'),
                  onPressed: () => _editReminder(null),
                ),
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            child: TextField(
              key: const Key('dateNote'),
              controller: _note,
              minLines: 1,
              maxLines: 6,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(labelText: 'Note'),
              onChanged: (text) => _change(_draft.copyWith(note: text)),
            ),
          ),
          if (saved)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 16, 24),
              child: Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  key: const Key('deleteDate'),
                  style: TextButton.styleFrom(foregroundColor: colors.danger),
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete date'),
                  onPressed: _delete,
                ),
              ),
            ),
        ],
      ),
    );
  }
}
