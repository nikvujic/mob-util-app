import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/sound.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/medicine.dart';
import 'package:the_app/pages/hub/medicine_sheet.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// The medicine tracker (O6): today's doses, one tap each to mark taken
/// (with the time); several a day show "1 of 2". The history lists every
/// day. Medicines are added at the bottom; tapping one's name edits or
/// deletes it.
class MedicinePage extends ConsumerWidget {
  const MedicinePage({super.key});

  DateTime _today(WidgetRef ref) => dayOf(ref.read(clockProvider)());

  Future<void> _add(BuildContext context, WidgetRef ref) async {
    final draft = await showMedicineSheet(context, today: _today(ref));
    if (draft == null) return;
    ref.read(medicineProvider.notifier).add(
          draft.name,
          times: draft.times,
          from: draft.from,
          until: draft.until,
        );
  }

  Future<void> _menu(
    BuildContext context,
    WidgetRef ref,
    Medicine medicine,
  ) async {
    final choice = await showModalBottomSheet<bool>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                medicine.name,
                style: const TextStyle(fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                _schedule(medicine, _today(ref)),
                style: TextStyle(color: context.colors.textSecondary),
              ),
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit'),
              onTap: () => Navigator.of(context).pop(true),
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline),
              title: const Text('Delete'),
              onTap: () => Navigator.of(context).pop(false),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    final notifier = ref.read(medicineProvider.notifier);
    if (choice) {
      final draft = await showMedicineSheet(
        context,
        today: _today(ref),
        medicine: medicine,
      );
      if (draft == null) return;
      notifier.update(
        medicine.id,
        name: draft.name,
        times: draft.times,
        from: draft.from,
        until: draft.until,
      );
      return;
    }
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${medicine.name}?',
      message: 'Its history goes too.',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed || !context.mounted) return;
    final before = notifier.remove(medicine.id);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text('${medicine.name} deleted'),
          action: SnackBarAction(
            label: 'Undo',
            onPressed: () => notifier.replaceAll(before),
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(medicineProvider);
    final today = dayOf(ref.watch(clockProvider)());
    final now = book.medicines.where((m) => m.isOn(today)).toList();
    final other = book.medicines.where((m) => !m.isOn(today)).toList();
    final doses = now.fold(0, (sum, m) => sum + m.dosesADay);
    final taken = [
      for (final m in now)
        for (var d = 0; d < m.dosesADay; d++)
          if (book.takenFor(m.id, today, d) != null) 1,
    ].length;
    final colors = context.colors;

    return Scaffold(
      appBar: AppBar(title: const Text('Medicine')),
      body: book.medicines.isEmpty
          ? const EmptyState(
              icon: Icons.medication_outlined,
              message: 'No medicines',
            )
          : PullDownList(
              bottomSpace: BottomActions.contentClearance,
              slivers: [
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      now.isEmpty
                          ? 'Nothing to take today'
                          : taken == doses
                              ? 'Today: all taken'
                              : 'Today: $taken of '
                                  '${countOf(doses, 'dose', 'doses')} taken',
                      key: const Key('medicineToday'),
                      style: TextStyle(
                        color: taken == doses && now.isNotEmpty
                            ? colors.accent
                            : colors.textSecondary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                // Today's, in the user's order: drag a card's handle.
                SliverReorderableList(
                  itemCount: now.length,
                  // onReorderItem only exists on newer Flutter than we
                  // target.
                  // ignore: deprecated_member_use
                  onReorder: (from, to) => ref
                      .read(medicineProvider.notifier)
                      .reorder([for (final m in now) m.id], from, to),
                  proxyDecorator: (child, _, __) => Material(
                    type: MaterialType.transparency,
                    elevation: 6,
                    child: child,
                  ),
                  itemBuilder: (context, index) {
                    final medicine = now[index];
                    return _MedicineCard(
                      key: ValueKey(medicine.id),
                      index: index,
                      medicine: medicine,
                      book: book,
                      day: today,
                      onOpen: () => _menu(context, ref, medicine),
                      onDose: (dose) {
                        final taking =
                            book.takenFor(medicine.id, today, dose) == null;
                        // Taken: a chime and a buzz (Nikola). Unticking
                        // is just a tap again, no undo needed.
                        if (taking) {
                          HapticFeedback.mediumImpact();
                          AppSound.done();
                        }
                        ref
                            .read(medicineProvider.notifier)
                            .toggleDose(medicine.id, today, dose);
                      },
                    );
                  },
                ),
                if (other.isNotEmpty)
                  SliverList.list(children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
                      child: Text(
                        'Not today',
                        style: TextStyle(color: colors.textSecondary),
                      ),
                    ),
                    for (final medicine in other)
                      ListTile(
                        title: Text(medicine.name),
                        subtitle: Text(
                          _schedule(medicine, today),
                          style: TextStyle(color: colors.textSecondary),
                        ),
                        onTap: () => _menu(context, ref, medicine),
                      ),
                  ]),
              ],
            ),
      // Always on the right: the hand can't be told from the touches
      // here (Nikola).
      floatingActionButton: BottomActions(
        side: HandSide.right,
        actions: [
          BottomAction(
            icon: Icons.history,
            tooltip: 'History',
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => const MedicineHistoryPage(),
              ),
            ),
          ),
          BottomAction(
            icon: Icons.add,
            tooltip: 'Add medicine',
            onPressed: () => _add(context, ref),
          ),
        ],
      ),
    );
  }
}

/// "08:00, 20:00 · from Thu, 1 Oct" (", until …" when it ends).
String _schedule(Medicine m, DateTime today) {
  final times = m.times.map(formatMinutes).join(', ');
  // No end date: nothing said about one (Nikola).
  final until =
      m.until == null ? '' : ', until ${formatDay(m.until!, today: today)}';
  return '$times · from ${formatDay(m.from, today: today)}$until';
}

/// A medicine's doses today: a big button each, taken or not.
class _MedicineCard extends StatelessWidget {
  final int index;
  final Medicine medicine;
  final MedicineBook book;
  final DateTime day;

  /// Its menu: a tap anywhere on the card but a dose (Nikola).
  final VoidCallback onOpen;
  final ValueChanged<int> onDose;

  const _MedicineCard({
    super.key,
    required this.index,
    required this.medicine,
    required this.book,
    required this.day,
    required this.onOpen,
    required this.onDose,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final several = medicine.dosesADay > 1;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      child: Material(
        color: colors.card,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          key: Key('medicineCard-${medicine.id}'),
          onTap: onOpen,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
                      child: Text(
                        medicine.name,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  // Drag here to move it (Nikola).
                  ReorderableDragStartListener(
                    index: index,
                    child: Semantics(
                      label: 'Move ${medicine.name}',
                      child: SizedBox.square(
                        dimension: kMinInteractiveDimension,
                        child: Icon(
                          Icons.drag_handle,
                          color: colors.textSecondary,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                // Two per row, always the same width; one dose takes the
                // first column, not the whole row (Nikola).
                child: LayoutBuilder(
                  builder: (context, box) {
                    const gap = 8.0;
                    final width = (box.maxWidth - gap) / 2;
                    return Wrap(
                      spacing: gap,
                      runSpacing: gap,
                      children: [
                        for (var dose = 0; dose < medicine.dosesADay; dose++)
                          SizedBox(
                            width: width,
                            child: _DoseButton(
                              key: Key('dose-${medicine.id}-$dose'),
                              label: several
                                  ? '${dose + 1} of ${medicine.dosesADay}'
                                  : null,
                              name: medicine.name,
                              time: medicine.times[dose],
                              taken: book.takenFor(medicine.id, day, dose),
                              onTap: () => onDose(dose),
                            ),
                          ),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One dose: its time, and "Taken 08:03" once tapped.
class _DoseButton extends StatelessWidget {
  final String? label;
  final String name;
  final int time;
  final DoseTaken? taken;
  final VoidCallback onTap;

  const _DoseButton({
    super.key,
    required this.label,
    required this.name,
    required this.time,
    required this.taken,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final done = taken != null;
    final at =
        done ? formatMinutes(taken!.at.hour * 60 + taken!.at.minute) : null;
    final fg =
        done ? (Theme.of(context).colorScheme.onPrimary) : colors.textPrimary;
    return Semantics(
      button: true,
      checked: done,
      label: '$name, ${label ?? 'dose'} at ${formatMinutes(time)}'
          '${done ? ', taken at $at' : ''}',
      excludeSemantics: true,
      child: Material(
        color: done ? colors.accent : colors.surface,
        shape: RoundedRectangleBorder(
          borderRadius: const BorderRadius.all(Radius.circular(14)),
          side: BorderSide(color: done ? colors.accent : colors.textHint),
        ),
        child: InkWell(
          customBorder: const RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(14)),
          ),
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              child: Row(
                children: [
                  Icon(
                    done ? Icons.check_circle : Icons.radio_button_unchecked,
                    color: done ? fg : colors.textSecondary,
                  ),
                  const SizedBox(width: 10),
                  // Shrinks with the box (half a card wide).
                  Flexible(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          formatMinutes(time),
                          style: TextStyle(
                            color: fg,
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          done ? 'Taken $at' : label ?? 'Tap when taken',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: done ? fg : colors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Every day back to the first medicine's start, newest first: each dose
/// with the time it was marked taken, or "not taken".
class MedicineHistoryPage extends ConsumerWidget {
  const MedicineHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(medicineProvider);
    final today = dayOf(ref.watch(clockProvider)());
    final colors = context.colors;
    final first = book.medicines.isEmpty
        ? today
        : book.medicines
            .map((m) => m.from)
            .reduce((a, b) => a.isBefore(b) ? a : b);
    final days = [
      for (var d = today; !d.isBefore(first); d = addDays(d, -1)) d,
    ];
    final rows = <Widget>[];
    for (final day in days) {
      final on = book.medicines.where((m) => m.isOn(day)).toList();
      if (on.isEmpty) continue;
      rows.add(Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
        child: Text(
          daysBetween(day, today) == 0 ? 'Today' : formatDay(day, today: today),
          style: TextStyle(
            color: colors.textSecondary,
            fontWeight: FontWeight.w600,
          ),
        ),
      ));
      for (final m in on) {
        rows.add(ListTile(
          title: Text(m.name),
          subtitle: Text(
            [
              for (var dose = 0; dose < m.dosesADay; dose++)
                switch (book.takenFor(m.id, day, dose)) {
                  final t? => '${formatMinutes(m.times[dose])} ✓ '
                      '${formatMinutes(t.at.hour * 60 + t.at.minute)}',
                  null => '${formatMinutes(m.times[dose])} not taken',
                },
            ].join('   '),
            style: TextStyle(color: colors.textSecondary),
          ),
        ));
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
