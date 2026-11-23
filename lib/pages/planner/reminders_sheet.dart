import 'package:flutter/material.dart';
import 'package:the_app/widgets/danger_button.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/planner_pin.dart';

/// What the reminders list asked for: a new reminder, the reminders
/// ticked to delete, or one to go to (its day, at its time).
typedef RemindersChoice = ({
  bool add,
  List<PlannerPin> delete,
  PlannerPin? goTo,
});

/// [pins] in the list's order: those still to come, the next
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

/// The planner's reminders, from its bell button: every one,
/// the next first, with its day and time; a button on each that goes to
/// it, a box on each to delete several at once, and a button to add one.
/// Null if closed.
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
    Widget tile(PlannerPin pin, {bool next = false}) => ListTile(
          key: Key('reminder-${pin.id}'),
          onTap: () => _toggle(pin),
          // Orange: the next one to come.
          leading: Icon(
            Icons.notifications_none,
            color: next ? colors.accent : colors.textSecondary,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                key: Key('reminderGoTo-${pin.id}'),
                tooltip: 'Go to it',
                icon: const Icon(Icons.arrow_forward),
                onPressed: () => Navigator.of(context)
                    .pop((add: false, delete: const <PlannerPin>[], goTo: pin)),
              ),
              Checkbox(
                value: _ticked.contains(pin.id),
                semanticLabel: 'Pick ${pin.title}',
                onChanged: (_) => _toggle(pin),
              ),
            ],
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
                  DangerButton(
                    key: const Key('remindersDelete'),
                    label: 'Delete ${ticked.length}',
                    wide: false,
                    onPressed: () => Navigator.of(context)
                        .pop((add: false, delete: ticked, goTo: null)),
                  ),
                const Spacer(),
                FilledButton.icon(
                  key: const Key('remindersAdd'),
                  onPressed: () => Navigator.of(context).pop(
                      (add: true, delete: const <PlannerPin>[], goTo: null)),
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
