import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/providers/backup_provider.dart';
import 'package:the_app/providers/counters_provider.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/notes_provider.dart';
import 'package:the_app/providers/pins_provider.dart';
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/providers/subscriptions_provider.dart';
import 'package:the_app/providers/packing_provider.dart';
import 'package:the_app/providers/recipes_provider.dart';
import 'package:the_app/providers/shop_provider.dart';
import 'package:the_app/providers/todo_provider.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';

/// Picks what to bring back from [backup] (Round 28): everything in it,
/// by kind, with boxes to tick; nothing is ticked at first. Returns the
/// ids picked, by kind, or null if left without restoring.
Future<Map<BackupPart, Set<String>>?> pickBackupParts(
  BuildContext context,
  RestorableBackup backup,
) =>
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => RestorePartPage(backup: backup)),
    );

/// One thing in the backup, as listed.
typedef _Entry = ({String id, String title, String? detail, bool locked});

class RestorePartPage extends ConsumerStatefulWidget {
  final RestorableBackup backup;

  const RestorePartPage({super.key, required this.backup});

  @override
  ConsumerState<RestorePartPage> createState() => _RestorePartPageState();
}

class _RestorePartPageState extends ConsumerState<RestorePartPage> {
  final _picked = <BackupPart, Set<String>>{
    for (final part in BackupPart.values) part: {},
  };

  int get _count => _picked.values.fold(0, (n, ids) => n + ids.length);

  static String _times(int start, int end) =>
      '${formatMinutes(start)}–${formatMinutes(end)}';

  static String _day(DateTime day) =>
      '${weekdayShort(day)} ${day.day}. ${day.month}. ${day.year}';

  /// Each kind's things in the backup, and the ids of those also in the
  /// app now (they come back as copies).
  List<(BackupPart, String, List<_Entry>, Set<String>)> _groups() {
    final b = widget.backup;
    _Entry plain(String id, String title, [String? detail]) =>
        (id: id, title: title, detail: detail, locked: false);
    Set<String> ids<T>(Iterable<T> items, String Function(T) idOf) =>
        {for (final i in items) idOf(i)};
    return [
      (
        BackupPart.notes,
        'Notes',
        [
          for (final n in b.notes)
            (
              id: n.id,
              title: n.title.isEmpty ? 'Untitled' : n.title,
              detail: formatDateTime(n.modifiedAt),
              locked: n.isLocked,
            ),
        ],
        ids(ref.watch(notesProvider), (n) => n.id),
      ),
      (
        BackupPart.todo,
        'To-do',
        [for (final t in b.todo) plain(t.id, t.text)],
        ids(ref.watch(todoProvider), (t) => t.id),
      ),
      (
        BackupPart.shop,
        'Shop',
        [
          for (final i in b.shopItems)
            plain(i.id, i.name, i.toBuy ? 'To buy' : null),
        ],
        ids(ref.watch(shopProvider), (i) => i.id),
      ),
      (
        BackupPart.tasks,
        'Planner tasks',
        [
          for (final t in b.plannerTasks)
            plain(
              t.id,
              t.title,
              t.hasTime
                  ? '${_day(t.day)}, ${_times(t.start!, t.end!)}'
                  : _day(t.day),
            ),
        ],
        const {},
      ),
      (
        BackupPart.routines,
        'Routines',
        [
          for (final r in b.routines)
            plain(r.id, r.title, _times(r.start, r.end)),
        ],
        const {},
      ),
      (
        BackupPart.reminders,
        'Reminders',
        [
          for (final p in b.plannerPins)
            plain(p.id, p.title, '${_day(p.day)}, ${formatMinutes(p.time)}'),
        ],
        ids(ref.watch(pinsProvider), (p) => p.id),
      ),
      (
        BackupPart.counters,
        'Counters',
        [for (final c in b.counters) plain(c.id, c.name, '${c.value}')],
        ids(ref.watch(countersProvider), (c) => c.id),
      ),
      (
        BackupPart.medicines,
        'Medicines',
        [
          for (final m in b.medicines) plain(m.id, m.name, 'With its history'),
        ],
        ids(ref.watch(medicineProvider).medicines, (m) => m.id),
      ),
      (
        BackupPart.recipes,
        'Recipes',
        [
          for (final r in b.recipes)
            plain(
              r.id,
              r.name.isEmpty ? 'Untitled' : r.name,
              countOf(r.ingredients.length, 'ingredient', 'ingredients'),
            ),
        ],
        ids(ref.watch(recipesProvider), (r) => r.id),
      ),
      (
        BackupPart.dates,
        'Dates',
        [
          for (final d in b.dates)
            plain(d.id, d.title, formatDayMonth(d.day, d.month, d.year)),
        ],
        ids(ref.watch(datesProvider).dates, (d) => d.id),
      ),
      (
        BackupPart.subscriptions,
        'Subscriptions',
        [
          for (final s in b.subscriptions) plain(s.id, s.name, s.state.label),
        ],
        ids(ref.watch(subscriptionsProvider).subscriptions, (s) => s.id),
      ),
      (
        BackupPart.packing,
        'Packing lists',
        [
          for (final l in b.packingLists)
            plain(l.id, l.name.trim().isEmpty ? 'Untitled' : l.name,
                l.items.length == 1 ? '1 item' : '${l.items.length} items'),
        ],
        ids(ref.watch(packingProvider).lists, (l) => l.id),
      ),
    ];
  }

  void _toggle(BackupPart part, String id) => setState(() {
        final ids = _picked[part]!;
        if (!ids.remove(id)) ids.add(id);
      });

  /// All of a kind, or none once all are picked.
  void _toggleAll(BackupPart part, List<_Entry> entries) => setState(() {
        final ids = _picked[part]!;
        if (ids.length == entries.length) {
          ids.clear();
        } else {
          ids.addAll(entries.map((e) => e.id));
        }
      });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final groups = [
      for (final g in _groups())
        if (g.$3.isNotEmpty) g,
    ];
    return Scaffold(
      appBar: AppBar(title: const Text('Restore part')),
      body: groups.isEmpty
          ? Center(
              child: Text(
                'This backup is empty',
                style: TextStyle(color: colors.textSecondary),
              ),
            )
          : PullDownList.children(
              bottomSpace: SelectionActions.listBottomSpace,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Text(
                    'Made ${formatDateTime(widget.backup.createdAt)}. Pick '
                    "what to bring back: it's added to what's in the app, "
                    'nothing is replaced.',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
                for (final (part, label, entries, inApp) in groups) ...[
                  ListTile(
                    key: Key('part-${part.name}'),
                    title: Text(
                      '${label.toUpperCase()}  ·  ${entries.length}',
                      style: TextStyle(
                        color: colors.accent,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        letterSpacing: 1,
                      ),
                    ),
                    trailing: TextButton(
                      onPressed: () => _toggleAll(part, entries),
                      child: Text(
                        _picked[part]!.length == entries.length
                            ? 'None'
                            : 'All',
                      ),
                    ),
                  ),
                  for (final e in entries)
                    CheckboxListTile(
                      key: Key('pick-${e.id}'),
                      value: _picked[part]!.contains(e.id),
                      onChanged: (_) => _toggle(part, e.id),
                      secondary: e.locked
                          ? Icon(Icons.lock_outline,
                              color: colors.textSecondary)
                          : null,
                      title: Text(e.title),
                      subtitle: e.detail == null && !inApp.contains(e.id)
                          ? null
                          : Text(
                              [
                                if (e.detail != null) e.detail!,
                                // Both are kept.
                                if (inApp.contains(e.id))
                                  'Also in the app: added as a copy',
                              ].join(' · '),
                              style: TextStyle(color: colors.textSecondary),
                            ),
                    ),
                ],
              ],
            ),
      // A wide button at the bottom, in thumb reach (Round 30: the round
      // one couldn't hold its label).
      bottomNavigationBar: _count == 0
          ? null
          : SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              child: FilledButton.icon(
                key: const Key('restorePicked'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                onPressed: () => Navigator.of(context).pop({
                  for (final MapEntry(:key, :value) in _picked.entries)
                    if (value.isNotEmpty) key: {...value},
                }),
                icon: const Icon(Icons.restore),
                label: Text('Restore $_count'),
              ),
            ),
    );
  }
}
