import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/planner_pin.dart';

/// What the reminders list asked for: a new reminder, or the reminders
/// ticked to delete.
typedef RemindersChoice = ({bool add, List<PlannerPin> delete});

/// [pins] in the list's order (Round 70): those still to come, the next
/// first; then those gone by unticked, the latest first.
({List<PlannerPin> coming, List<PlannerPin> past}) sortPins(
  List<PlannerPin> pins,
  DateTime now,
) {
  DateTime at(PlannerPin p) =>
      DateTime(p.day.year, p.day.month, p.day.day, p.time ~/ 60, p.time % 60);
  final coming = [
    for (final p in pins)
      if (!at(p).isBefore(now)) p
  ]..sort((a, b) => at(a).compareTo(at(b)));
  final past = [
    for (final p in pins)
      if (at(p).isBefore(now)) p
  ]..sort((a, b) => at(b).compareTo(at(a)));
  return (coming: coming, past: past);
}

/// The planner's reminders (Round 70), from its bell button: every one,
/// the next first, with its day and time; a box on each to delete several
/// at once, and a button to add one. Null if closed.
Future<RemindersChoice?> showRemindersSheet(
  BuildContext context, {
  required List<PlannerPin> pins,
  required DateTime now,
}) =>
    showModalBottomSheet<RemindersChoice>(
      context: context,
      builder: (_) => _RemindersSheet(pins: pins, now: now),
    );

class _RemindersSheet extends StatefulWidget {
  final List<PlannerPin> pins;
  final DateTime now;

  const _RemindersSheet({required this.pins, required this.now});

  @override
  State<_RemindersSheet> createState() => _RemindersSheetState();
}

class _RemindersSheetState extends State<_RemindersSheet> {
  final _ticked = <String>{};

  void _toggle(PlannerPin pin) => setState(() {
        if (!_ticked.remove(pin.id)) _ticked.add(pin.id);
      });

  /// "Today · 14:30", "Tomorrow · 09:00", "Thu, 23 Oct · 09:00".
  String _when(PlannerPin pin) {
    final today = DateTime(widget.now.year, widget.now.month, widget.now.day);
    final day = switch (daysBetween(today, pin.day)) {
      0 => 'Today',
      1 => 'Tomorrow',
      -1 => 'Yesterday',
      _ => formatDay(pin.day, today: today),
    };
    return '$day · ${formatMinutes(pin.time)}';
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (:coming, :past) = sortPins(widget.pins, widget.now);
    Widget tile(PlannerPin pin, {bool next = false}) => CheckboxListTile(
          key: Key('reminder-${pin.id}'),
          value: _ticked.contains(pin.id),
          onChanged: (_) => _toggle(pin),
          secondary: Icon(
            Icons.notifications_none,
            color: next ? colors.accent : colors.textSecondary,
          ),
          title: Text(
            pin.title,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Text(
            next ? 'Next · ${_when(pin)}' : _when(pin),
            style: TextStyle(color: colors.textSecondary),
          ),
        );
    Widget header(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Text(
            text,
            style: TextStyle(
              color: colors.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
        );
    final ticked = [
      for (final p in widget.pins)
        if (_ticked.contains(p.id)) p
    ];
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
            child: Text(
              'Reminders',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Flexible(
            // Scrolls only when there are many; it's at the bottom already.
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (coming.isNotEmpty) header('Coming'),
                  for (final (i, pin) in coming.indexed)
                    tile(pin, next: i == 0),
                  if (past.isNotEmpty) header('Gone by, not ticked off'),
                  for (final pin in past) tile(pin),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                if (ticked.isNotEmpty)
                  TextButton.icon(
                    key: const Key('remindersDelete'),
                    style: TextButton.styleFrom(
                      foregroundColor: colors.danger,
                    ),
                    onPressed: () =>
                        Navigator.of(context).pop((add: false, delete: ticked)),
                    icon: const Icon(Icons.delete_outline),
                    label: Text('Delete ${ticked.length}'),
                  ),
                const Spacer(),
                FilledButton.icon(
                  key: const Key('remindersAdd'),
                  onPressed: () => Navigator.of(context)
                      .pop((add: true, delete: const <PlannerPin>[])),
                  icon: const Icon(Icons.add_alert_outlined),
                  label: const Text('Add reminder'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
