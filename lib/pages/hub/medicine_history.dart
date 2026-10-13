import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/pages/hub/medicine_calendar.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// How a day went for some doses: all taken, some missed, …
enum DayOutcome {
  /// Every dose taken.
  taken,

  /// Some taken, the rest not set yet.
  partly,

  /// A dose missed.
  missed,

  /// Something not sure, nothing missed.
  unsure,

  /// Nothing set.
  none,
}

/// How [day] went for [medicines] in [book].
DayOutcome outcomeOf(
  MedicineBook book,
  Iterable<Medicine> medicines,
  DateTime day,
) {
  var doses = 0, taken = 0, missed = 0, unsure = 0;
  for (final m in medicines) {
    if (!m.isOn(day)) continue;
    for (var d = 0; d < m.dosesADay; d++) {
      doses++;
      switch (book.markFor(m.id, day, d)?.state) {
        case DoseState.taken:
          taken++;
        case DoseState.missed:
          missed++;
        case DoseState.unsure:
          unsure++;
        case null:
          break;
      }
    }
  }
  if (doses == 0) return DayOutcome.none;
  if (missed > 0) return DayOutcome.missed;
  if (taken == doses) return DayOutcome.taken;
  if (unsure > 0) return DayOutcome.unsure;
  return taken > 0 ? DayOutcome.partly : DayOutcome.none;
}

/// The colour of a day that went as [outcome].
Color outcomeColour(BuildContext context, DayOutcome outcome) {
  final colors = context.colors;
  return switch (outcome) {
    DayOutcome.taken => DoseColours.taken,
    DayOutcome.partly => DoseColours.taken.withValues(alpha: 0.45),
    DayOutcome.missed => DoseColours.missed,
    DayOutcome.unsure => DoseColours.unsure,
    DayOutcome.none => colors.card,
  };
}

/// Lets the user set what became of a dose (O13): taken, missed, not sure,
/// or nothing.
Future<void> showDoseSheet(
  BuildContext context,
  WidgetRef ref, {
  required Medicine medicine,
  required DateTime day,
  required int dose,
}) async {
  final today = dayOf(ref.read(clockProvider)());
  final current = ref.read(medicineProvider).markFor(medicine.id, day, dose);
  final picked = await showModalBottomSheet<(DoseState?,)>(
    context: context,
    builder: (context) {
      final colors = context.colors;
      Widget choice(DoseState? state, IconData icon, String label) => ListTile(
            leading: Icon(icon, color: _markColour(context, state)),
            title: Text(label),
            selected: current?.state == state,
            onTap: () => Navigator.of(context).pop((state,)),
          );
      return SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                medicine.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                '${formatDay(day, today: today)} · '
                '${formatMinutes(medicine.times[dose])}',
                style: TextStyle(color: colors.textSecondary),
              ),
            ),
            choice(DoseState.taken, Icons.check_circle, 'Taken'),
            choice(DoseState.missed, Icons.cancel, 'Missed'),
            choice(DoseState.unsure, Icons.help, 'Not sure'),
            choice(null, Icons.radio_button_unchecked, 'Not set'),
          ],
        ),
      );
    },
  );
  if (picked == null) return;
  ref
      .read(medicineProvider.notifier)
      .setDose(medicine.id, day, dose, picked.$1);
}

Color _markColour(BuildContext context, DoseState? state) {
  final colors = context.colors;
  return switch (state) {
    DoseState.taken => DoseColours.taken,
    DoseState.missed => DoseColours.missed,
    DoseState.unsure => DoseColours.unsure,
    null => colors.textHint,
  };
}

/// One dose in a history: its time, and how it went (with the time it was
/// ticked); tap to change it.
class DoseMarkChip extends ConsumerWidget {
  final Medicine medicine;
  final DateTime day;
  final int dose;

  const DoseMarkChip({
    super.key,
    required this.medicine,
    required this.day,
    required this.dose,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final mark = ref.watch(medicineProvider).markFor(medicine.id, day, dose);
    final at = mark?.at;
    final state = mark?.state;
    final (icon, text) = switch (state) {
      DoseState.taken => (
          Icons.check_circle,
          at == null ? 'taken' : formatMinutes(at.hour * 60 + at.minute),
        ),
      DoseState.missed => (Icons.cancel, 'missed'),
      DoseState.unsure => (Icons.help, 'not sure'),
      null => (Icons.radio_button_unchecked, 'not set'),
    };
    final time = formatMinutes(medicine.times[dose]);
    return Semantics(
      button: true,
      label: '$time: $text',
      excludeSemantics: true,
      child: InkWell(
        key: Key('mark-${medicine.id}-${PlannerDay.key(day)}-$dose'),
        borderRadius: BorderRadius.circular(18),
        onTap: () => showDoseSheet(
          context,
          ref,
          medicine: medicine,
          day: day,
          dose: dose,
        ),
        child: Container(
          constraints: const BoxConstraints(minHeight: 48),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.divider),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 20, color: _markColour(context, state)),
              const SizedBox(width: 6),
              Text(time, style: TextStyle(color: colors.textPrimary)),
              const SizedBox(width: 6),
              Text(text, style: TextStyle(color: colors.textSecondary)),
            ],
          ),
        ),
      ),
    );
  }
}

/// A day's key for widget keys: `2026-10-12`.
abstract final class PlannerDay {
  static String key(DateTime day) =>
      '${day.year}-${day.month.toString().padLeft(2, '0')}-'
      '${day.day.toString().padLeft(2, '0')}';
}

/// A day's title in a history: coloured by how the day went.
class _DayTitle extends StatelessWidget {
  final DateTime day;
  final DateTime today;
  final DayOutcome outcome;

  const _DayTitle({
    required this.day,
    required this.today,
    required this.outcome,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colour = switch (outcome) {
      DayOutcome.taken => DoseColours.taken,
      DayOutcome.missed => DoseColours.missed,
      _ => colors.textPrimary,
    };
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 18, 16, 6),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              color: outcomeColour(context, outcome),
              shape: BoxShape.circle,
              border: Border.all(color: colors.textHint),
            ),
          ),
          const SizedBox(width: 8),
          Text(
            daysBetween(day, today) == 0
                ? 'Today'
                : formatDay(day, today: today),
            style: TextStyle(
              color: colour,
              fontWeight: FontWeight.w700,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

/// A medicine's doses on a day: its name (unless [showName] is off) and a
/// mark per dose.
class _DayDoses extends StatelessWidget {
  final Medicine medicine;
  final DateTime day;
  final bool showName;

  const _DayDoses({
    required this.medicine,
    required this.day,
    this.showName = true,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 2, 16, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showName)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                medicine.name,
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            children: [
              for (var dose = 0; dose < medicine.dosesADay; dose++)
                DoseMarkChip(medicine: medicine, day: day, dose: dose),
            ],
          ),
        ],
      ),
    );
  }
}

/// Every day back to the first medicine's start, newest first: a coloured
/// title per day and a mark per dose, each settable (O13).
class MedicineHistoryPage extends ConsumerWidget {
  const MedicineHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(medicineProvider);
    final today = dayOf(ref.watch(clockProvider)());
    final first = book.medicines.isEmpty
        ? today
        : book.medicines
            .map((m) => m.from)
            .reduce((a, b) => a.isBefore(b) ? a : b);
    final rows = <Widget>[];
    for (var day = today; !day.isBefore(first); day = addDays(day, -1)) {
      final on = book.medicines.where((m) => m.isOn(day)).toList();
      if (on.isEmpty) continue;
      rows.add(_DayTitle(
        day: day,
        today: today,
        outcome: outcomeOf(book, on, day),
      ));
      for (final m in on) {
        rows.add(_DayDoses(medicine: m, day: day));
      }
    }
    return Scaffold(
      appBar: AppBar(title: const Text('Medicine history')),
      body: rows.isEmpty
          ? const EmptyState(icon: Icons.history, message: 'No history yet')
          : PullDownList.children(children: rows),
    );
  }
}

/// One medicine's history (O13): how many were ever taken, a month
/// calendar of its days (Round 16; older months to the left), and
/// every day below, each dose settable. Past days not set yet can be filled
/// in as taken in one go.
class MedicineOwnHistoryPage extends ConsumerStatefulWidget {
  final String id;

  /// Opens scrolled to this day (from the history of all, Round 18).
  final DateTime? day;

  const MedicineOwnHistoryPage({super.key, required this.id, this.day});

  @override
  ConsumerState<MedicineOwnHistoryPage> createState() =>
      _MedicineOwnHistoryPageState();
}

class _MedicineOwnHistoryPageState
    extends ConsumerState<MedicineOwnHistoryPage> {
  /// The top of the list, to reach its scroll position.
  final _header = GlobalKey();

  /// The days built so far (the list builds them as they come into view).
  final _dayKeys = <DateTime, GlobalKey>{};

  GlobalKey _keyFor(DateTime day) => _dayKeys.putIfAbsent(day, GlobalKey.new);

  @override
  void initState() {
    super.initState();
    final day = widget.day;
    if (day != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showDay(day));
    }
  }

  /// Scrolls the list to [day]'s entry. Days are built only near the
  /// screen (thousands over the years), so first a jump to about where it
  /// is, then steps until it's built, then exactly to it.
  Future<void> _showDay(DateTime day) async {
    final days = _days();
    final index = days.indexWhere((d) => daysBetween(d, day) == 0);
    if (index < 0) return;
    // Taken now: the top of the list goes as it scrolls away.
    final listContext = _header.currentContext;
    if (listContext == null) return;
    final position = Scrollable.of(listContext).position;
    for (var tries = 0; tries < 60; tries++) {
      if (!mounted) return;
      final target = _dayKeys[days[index]]?.currentContext;
      if (target != null && target.mounted) {
        await Scrollable.ensureVisible(
          target,
          alignment: 0.05,
          duration: const Duration(milliseconds: 250),
        );
        return;
      }
      // Where it'd be if the days were spread evenly over what's known.
      final built = _dayKeys.entries
          .where((e) => e.value.currentContext != null)
          .map((e) => days.indexWhere((d) => daysBetween(d, e.key) == 0))
          .where((i) => i >= 0)
          .toList();
      final ahead = built.isEmpty || index > built.reduce(math.max);
      final step = position.viewportDimension * 0.9;
      position.jumpTo(
        (position.pixels + (ahead ? step : -step))
            .clamp(position.minScrollExtent, position.maxScrollExtent),
      );
      await WidgetsBinding.instance.endOfFrame;
    }
  }

  Medicine? get _medicine => ref
      .read(medicineProvider)
      .medicines
      .where((m) => m.id == widget.id)
      .firstOrNull;

  /// Its days, newest first.
  List<DateTime> _days() {
    final medicine = _medicine;
    if (medicine == null) return const [];
    final today = dayOf(ref.read(clockProvider)());
    final last = medicine.until != null && medicine.until!.isBefore(today)
        ? medicine.until!
        : today;
    return [
      for (var d = last; !d.isBefore(medicine.from); d = addDays(d, -1)) d,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final book = ref.watch(medicineProvider);
    final medicine = book.medicines.where((m) => m.id == widget.id).firstOrNull;
    if (medicine == null) {
      return Scaffold(appBar: AppBar(title: const Text('History')));
    }
    final today = dayOf(ref.watch(clockProvider)());
    final colors = context.colors;
    final days = _days();
    final unset = book.offersFillPast(medicine, today);
    final total = book.takenCount(widget.id);
    return Scaffold(
      appBar: AppBar(title: Text(medicine.name)),
      body: PullDownList(
        slivers: [
          SliverList.list(
            children: [
              Padding(
                key: _header,
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Text(
                  countOf(total, 'dose', 'doses'),
                  key: const Key('medicineTotal'),
                  style: TextStyle(
                    color: colors.accent,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                child: Text(
                  'taken since ${formatDay(medicine.from, today: today)}',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              // A day tapped shows it below; it isn't changed from here
              // (Round 18).
              MedicineCalendar(
                medicine: medicine,
                book: book,
                today: today,
                onDay: _showDay,
              ),
              if (unset)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const Key('fillPast'),
                      onPressed: () => _fill(context, ref, medicine),
                      icon: const Icon(Icons.done_all, size: 18),
                      label: const Text('Mark past days taken'),
                    ),
                  ),
                ),
            ],
          ),
          // Built as they come into view: years of days stay quick.
          SliverList.builder(
            itemCount: days.length,
            itemBuilder: (context, index) {
              final day = days[index];
              return Column(
                key: _keyFor(day),
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _DayTitle(
                    day: day,
                    today: today,
                    outcome: outcomeOf(book, [medicine], day),
                  ),
                  _DayDoses(medicine: medicine, day: day, showName: false),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _fill(
    BuildContext context,
    WidgetRef ref,
    Medicine medicine,
  ) async {
    final marked = ref.read(medicineProvider.notifier).fillPast(medicine.id);
    if (!context.mounted || marked == 0) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
            content: Text('${countOf(marked, 'dose', 'doses')} marked taken')),
      );
  }
}
