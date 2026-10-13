import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/widgets/app_dialog.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// What the medicine sheet gives back.
typedef MedicineDraft = ({
  String name,
  List<int> times,
  DateTime from,
  DateTime? until,
  int? followUp,
  bool important,
});

/// "Remind again" choices, in minutes after a dose (0: off).
const followUpChoices = [0, 60, 120, 180, 240];

/// The sheet to add a medicine, or edit [medicine] (O6): its name, the
/// time of each dose (how many a day = how many times), from when until
/// when (or for good), whether to remind again if a dose isn't taken
/// (Round 16), and whether it's important (Round 24). Null if closed.
///
/// Like the routines' sheet (Round 24): it scrolls (pulling down is reach
/// mode, not closing), and only back closes it, asking first when
/// something changed.
Future<MedicineDraft?> showMedicineSheet(
  BuildContext context, {
  required DateTime today,
  Medicine? medicine,
}) {
  return showModalBottomSheet<MedicineDraft>(
    context: context,
    isScrollControlled: true,
    enableDrag: false,
    isDismissible: false,
    builder: (_) => _MedicineSheet(today: today, medicine: medicine),
  );
}

class _MedicineSheet extends StatefulWidget {
  final DateTime today;
  final Medicine? medicine;

  const _MedicineSheet({required this.today, this.medicine});

  @override
  State<_MedicineSheet> createState() => _MedicineSheetState();
}

class _MedicineSheetState extends State<_MedicineSheet> {
  late final _name = TextEditingController(text: widget.medicine?.name ?? '')
    ..addListener(() => setState(() {}));

  /// One per dose, in order. A new medicine: once a day, at 08:00.
  late final List<int> _times = [...?widget.medicine?.times];
  late DateTime _from = widget.medicine?.from ?? widget.today;
  late DateTime? _until = widget.medicine?.until;
  late int _followUp = widget.medicine?.followUp ?? 0;
  late bool _important = widget.medicine?.important ?? false;

  /// The times it opened with.
  late final List<int> _initialTimes = [..._times];

  bool get _changed =>
      _name.text.trim() != (widget.medicine?.name ?? '') ||
      !_sameTimes ||
      _from != (widget.medicine?.from ?? widget.today) ||
      _until != widget.medicine?.until ||
      _followUp != (widget.medicine?.followUp ?? 0) ||
      _important != (widget.medicine?.important ?? false);

  bool get _sameTimes {
    final a = [..._times]..sort();
    final b = [..._initialTimes]..sort();
    return a.length == b.length &&
        [for (var i = 0; i < a.length; i++) a[i] == b[i]].every((s) => s);
  }

  /// Back: closes, asking first if something changed.
  Future<void> _close() async {
    if (!_changed) {
      Navigator.of(context).pop();
      return;
    }
    final discard = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AppDialog(
        title: 'Discard changes?',
        content: const DialogMessage("What you changed here won't be kept."),
        actions: [
          DialogButton(
            label: 'Cancel',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          DialogButton(
            label: 'Discard',
            primary: true,
            danger: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    if (discard == true && mounted) Navigator.of(context).pop();
  }

  @override
  void initState() {
    super.initState();
    if (_times.isEmpty) _times.add(8 * 60);
    _initialTimes; // as opened
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  /// The most doses a day it offers.
  static const maxDoses = 8;

  Future<int?> _pickTime(int initial) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: initial ~/ 60, minute: initial % 60),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    return picked == null ? null : picked.hour * 60 + picked.minute;
  }

  Future<void> _editTime(int index) async {
    final picked = await _pickTime(_times[index]);
    if (picked != null && mounted) {
      setState(() => _times[index] = picked);
    }
  }

  /// Another dose, a few hours after the last (within the day).
  void _addTime() => setState(() {
        final last = _times.reduce((a, b) => a > b ? a : b);
        _times.add((last + 4 * 60).clamp(0, 23 * 60 + 59));
      });

  Future<void> _pickDate({required bool until}) async {
    final first = until ? _from : DateTime(widget.today.year - 5);
    final initial = until ? (_until ?? addDays(_from, 7)) : _from;
    final picked = await showDatePicker(
      context: context,
      initialDate: initial.isBefore(first) ? first : initial,
      firstDate: first,
      lastDate: DateTime(widget.today.year + 10),
    );
    if (picked == null || !mounted) return;
    setState(() {
      if (until) {
        _until = picked;
      } else {
        _from = picked;
        // The end can't come before the start.
        if (_until != null && _until!.isBefore(_from)) _until = _from;
      }
    });
  }

  bool get _valid => _name.text.trim().isNotEmpty && _times.isNotEmpty;

  void _submit() {
    if (!_valid) return;
    Navigator.of(context).pop<MedicineDraft>((
      name: _name.text.trim(),
      times: [..._times]..sort(),
      from: _from,
      until: _until,
      followUp: _followUp == 0 ? null : _followUp,
      important: _important,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = TextStyle(color: colors.textSecondary);
    final sorted = [
      for (var i = 0; i < _times.length; i++) (i, _times[i]),
    ]..sort((a, b) => a.$2.compareTo(b.$2));
    String day(DateTime d) => formatDay(d, today: widget.today);
    final media = MediaQuery.of(context);
    // A fixed share of the room above the keyboard, like the routines'
    // sheet: the fields scroll, the button stays at the bottom.
    final room =
        media.size.height - media.viewInsets.bottom - media.padding.top;
    return PopScope(
      canPop: !_changed,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _close();
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: media.viewInsets.bottom),
        child: SizedBox(
          height: room * 0.8,
          child: Column(
            children: [
              Expanded(
                child: PullDownList.children(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          TextField(
                            key: const Key('medicineName'),
                            controller: _name,
                            autofocus: widget.medicine == null,
                            textCapitalization: TextCapitalization.sentences,
                            decoration:
                                const InputDecoration(labelText: 'Medicine'),
                          ),
                          const SizedBox(height: 12),
                          Text(
                            _times.length == 1
                                ? 'Once a day, at'
                                : '${_times.length} times a day, at',
                            style: label,
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              for (final (index, minutes) in sorted)
                                InputChip(
                                  key: Key('medicineTime-$index'),
                                  label: Text(formatMinutes(minutes)),
                                  onPressed: () => _editTime(index),
                                  // At least one dose.
                                  onDeleted: _times.length > 1
                                      ? () =>
                                          setState(() => _times.removeAt(index))
                                      : null,
                                  deleteButtonTooltipMessage:
                                      'Remove this dose',
                                ),
                              if (_times.length < maxDoses)
                                ActionChip(
                                  key: const Key('medicineAddTime'),
                                  avatar: const Icon(Icons.add, size: 18),
                                  label: const Text('Dose'),
                                  onPressed: _addTime,
                                ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('From', style: label),
                              ActionChip(
                                key: const Key('medicineFrom'),
                                label: Text(day(_from)),
                                onPressed: () => _pickDate(until: false),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text('Until', style: label),
                              ChoiceChip(
                                label: const Text('For good'),
                                selected: _until == null,
                                onSelected: (_) =>
                                    setState(() => _until = null),
                              ),
                              ChoiceChip(
                                key: const Key('medicineUntil'),
                                label: Text(
                                    _until == null ? 'A date…' : day(_until!)),
                                selected: _until != null,
                                onSelected: (_) => _pickDate(until: true),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text('Remind again if not taken', style: label),
                          Wrap(
                            spacing: 8,
                            children: [
                              for (final minutes in followUpChoices)
                                ChoiceChip(
                                  key: Key('followUp-$minutes'),
                                  label: Text(
                                    minutes == 0
                                        ? 'No'
                                        : '${minutes ~/ 60} h later',
                                  ),
                                  selected: _followUp == minutes,
                                  onSelected: (_) =>
                                      setState(() => _followUp = minutes),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    // Important (Round 24): what it does, said here.
                    SwitchListTile(
                      key: const Key('medicineImportant'),
                      secondary: const Icon(Icons.priority_high),
                      title: const Text('Important'),
                      subtitle: Text(
                        'Taking a dose needs the button held for 5 seconds, '
                        "so it isn't ticked by mistake. The red dot on the "
                        "Hub shows while one of its doses is due and not "
                        'taken.',
                        style: label,
                      ),
                      value: _important,
                      onChanged: (on) => setState(() => _important = on),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: colors.divider),
              SafeArea(
                top: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                  child: Row(
                    // No ✕: back closes it (asking first if something
                    // changed).
                    children: [
                      const Spacer(),
                      FilledButton(
                        key: const Key('medicineSubmit'),
                        onPressed: _valid ? _submit : null,
                        child: Text(widget.medicine == null ? 'Add' : 'Save'),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
