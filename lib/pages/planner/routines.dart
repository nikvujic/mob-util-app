import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/routine.dart';
import 'package:the_app/pages/planner/add_task_sheet.dart';
import 'package:the_app/pages/planner/timeline.dart';
import 'package:the_app/providers/planner_provider.dart';
import 'package:the_app/providers/reminders_provider.dart';
import 'package:the_app/providers/routines_provider.dart';
import 'package:the_app/widgets/confirm_dialog.dart';

/// After a reminder was set ([remind] not null): makes sure notifications
/// may be shown, asking Android if needed (P10), and says so if not.
Future<void> allowReminders(
  BuildContext context,
  WidgetRef ref,
  int? remind,
) async {
  if (remind == null) return;
  final messenger = ScaffoldMessenger.of(context);
  if (await ref.read(reminderPlannerProvider).requestPermission()) return;
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      const SnackBar(
        content: Text(
          'Notifications are off for this app, so reminders won\'t show. '
          'They can be turned on in Android\'s settings.',
        ),
      ),
    );
}

/// Edits [routine] everywhere it's on (P8), or deletes it after asking.
Future<void> editRoutine(
  BuildContext context,
  WidgetRef ref,
  Routine routine,
) async {
  final routines = ref.read(routinesProvider.notifier);
  final messenger = ScaffoldMessenger.of(context);
  var delete = false;
  final changed = await showEditRoutineSheet(
    context,
    routine,
    routines.roomFor(routine),
    onDelete: () => delete = true,
  );
  if (!context.mounted) return;
  if (delete) {
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete routine?',
      message: '${routine.title} goes from every day, past ones too. '
          'This cannot be undone.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (confirmed) routines.remove(routine.id);
    return;
  }
  if (changed == null) return;
  try {
    routines.update(
      routine.id,
      title: changed.title,
      start: changed.start,
      end: changed.end,
      weekdays: changed.weekdays ?? routine.weekdays,
      until: changed.until,
      color: changed.color,
      remind: changed.remind,
    );
    if (context.mounted) await allowReminders(context, ref, changed.remind);
  } on TaskOverlapException {
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text('Another routine has that time on one of those days.'),
        ),
      );
  }
}

/// The routines (P8), one weekday at a time: the same timeline as a day,
/// with a Mon–Sun strip to pick the weekday. Tapping free time adds a
/// routine on that weekday (more days can be ticked); tapping a routine
/// edits or deletes it everywhere. Shows routines that haven't ended.
class RoutinesPage extends ConsumerStatefulWidget {
  /// The weekday shown first ([DateTime.monday] to [DateTime.sunday]).
  final int weekday;

  const RoutinesPage({super.key, required this.weekday});

  @override
  ConsumerState<RoutinesPage> createState() => _RoutinesPageState();
}

class _RoutinesPageState extends ConsumerState<RoutinesPage> {
  late int _weekday = widget.weekday;
  late final ScrollController _timeline;

  @override
  void initState() {
    super.initState();
    final now = ref.read(clockProvider)();
    _timeline = ScrollController(
      initialScrollOffset:
          math.max(0, now.hour - 1) * PlannerTimeline.hourHeight,
    );
  }

  @override
  void dispose() {
    _timeline.dispose();
    super.dispose();
  }

  DateTime get _today => dayOf(ref.read(clockProvider)());

  Future<void> _add(FreeSlot slot) async {
    final today = _today;
    final added = await showAddRoutineSheet(
      context,
      slot,
      weekday: _weekday,
      from: today,
    );
    if (added == null || !mounted) return;
    try {
      ref.read(routinesProvider.notifier).add(
            title: added.title,
            start: added.start,
            end: added.end,
            weekdays: added.weekdays ?? {_weekday},
            from: today,
            until: added.until,
            color: added.color,
            remind: added.remind,
          );
      await allowReminders(context, ref, added.remind);
    } on TaskOverlapException {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content:
                Text('Another routine has that time on one of those days.'),
          ),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final today = _today;
    final shown = [
      for (final r in ref.watch(routinesProvider).routines)
        if (r.weekdays.contains(_weekday) &&
            (r.until == null || !r.until!.isBefore(today)))
          r,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Routines')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Every ${weekdayNameLong(_weekday)}',
                style: TextStyle(
                  color: context.colors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              controller: _timeline,
              child: PlannerTimeline(
                adds: 'a routine',
                blocks: [
                  for (final r in shown)
                    TimelineBlock(
                      id: r.id,
                      title: r.title,
                      start: r.start,
                      end: r.end,
                      repeats: true,
                      color: BlockColor.fromName(r.color),
                      onTap: () => editRoutine(context, ref, r),
                    ),
                ],
                onAdd: _add,
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: _WeekdayStrip(
        selected: _weekday,
        onSelected: (day) => setState(() => _weekday = day),
      ),
    );
  }
}

/// Mon–Sun, to pick the weekday shown.
class _WeekdayStrip extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;

  const _WeekdayStrip({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Material(
      color: colors.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
          child: Row(
            children: [
              for (var day = 1; day <= 7; day++)
                Expanded(
                  child: Semantics(
                    selected: day == selected,
                    button: true,
                    label: weekdayNameLong(day),
                    excludeSemantics: true,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(14),
                      onTap: () => onSelected(day),
                      child: Container(
                        height: 48,
                        margin: const EdgeInsets.symmetric(horizontal: 2),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: day == selected
                                ? colors.accent
                                : Colors.transparent,
                            width: 2,
                          ),
                        ),
                        child: Text(
                          weekdayName(day),
                          style: TextStyle(
                            color: day == selected
                                ? colors.textPrimary
                                : colors.textSecondary,
                            fontWeight: day == selected
                                ? FontWeight.w700
                                : FontWeight.w400,
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
    );
  }
}
