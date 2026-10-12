import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/sound.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/counter.dart';
import 'package:the_app/pages/other/counter_sheet.dart';
import 'package:the_app/providers/counters_provider.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';

/// Counters (O2): each with its name, its value and big − / + buttons.
/// Long-press selects them to reset, rename or delete; the handle
/// reorders.
class CountersPage extends ConsumerStatefulWidget {
  const CountersPage({super.key});

  @override
  ConsumerState<CountersPage> createState() => _CountersPageState();
}

class _CountersPageState extends ConsumerState<CountersPage> {
  final SelectionController _selection = SelectionController();

  CountersNotifier get _notifier => ref.read(countersProvider.notifier);

  /// Counts, with a click and a short vibration if switched on (U6).
  void _step(String id, int by) {
    if (ref.read(preferencesProvider).counterFeedback) {
      HapticFeedback.mediumImpact();
      AppSound.click();
    }
    _notifier.step(id, by);
  }

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  /// A new counter, with its options (O5).
  Future<void> _add() async {
    final options = await showCounterSheet(context);
    if (options != null && mounted) {
      _notifier.add(options.name, options: options);
    }
  }

  /// Its name and options, from selection mode.
  Future<void> _editSelected() async {
    final id = _selection.selected.single;
    final counter = ref.read(countersProvider).firstWhere((c) => c.id == id);
    final options = await showCounterSheet(context, counter: counter);
    if (options == null || !mounted) return;
    _notifier.edit(id, options);
    _selection.clear();
  }

  Future<void> _resetSelected() async {
    final count = _selection.count;
    final confirmed = await showConfirmDialog(
      context,
      title: count == 1
          ? 'Reset counter?'
          : 'Reset ${countOf(count, 'counter', 'counters')}?',
      message: 'The value goes back to 0 (or its limit, if 0 is outside).',
      confirmLabel: 'Reset',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    _notifier.reset(_selection.selected);
    _selection.clear();
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      count: _selection.count,
      singular: 'counter',
      plural: 'counters',
    );
    if (!confirmed || !mounted) return;
    _notifier.remove(_selection.selected);
    _selection.clear();
  }

  @override
  Widget build(BuildContext context) {
    final counters = ref.watch(countersProvider);
    ref.listen(countersProvider, (_, next) {
      _selection.retain(next.map((c) => c.id));
    });

    return SelectionPopScope(
      controller: _selection,
      child: ListenableBuilder(
        listenable: _selection,
        builder: (context, _) => Scaffold(
          appBar: _selection.isActive
              ? SelectionAppBar(count: _selection.count)
              : AppBar(title: const Text('Counters')),
          body: counters.isEmpty
              ? const EmptyState(
                  icon: Icons.exposure_plus_1,
                  message: 'No counters',
                )
              : PullDownList(
                  bottomSpace: SelectionActions.listBottomSpace,
                  // Counter rows are big: reach a bit further (U4).
                  reachShare: 0.35,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 4),
                      sliver: SliverReorderableList(
                        itemCount: counters.length,
                        // onReorderItem only exists on newer Flutter than we
                        // target.
                        // ignore: deprecated_member_use
                        onReorder: _notifier.reorder,
                        proxyDecorator: (child, _, __) => Material(
                          type: MaterialType.transparency,
                          elevation: 6,
                          child: child,
                        ),
                        itemBuilder: (context, index) {
                          final counter = counters[index];
                          return Padding(
                            key: ValueKey(counter.id),
                            // Room around each card (O5).
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            child: _CounterCard(
                              counter: counter,
                              index: index,
                              selectionMode: _selection.isActive,
                              selected: _selection.isSelected(counter.id),
                              onStep: (by) => _step(counter.id, by),
                              // Counting is done with the buttons; a tap on
                              // the card only matters while selecting.
                              onTap: () =>
                                  _selection.handleTap(counter.id, () {}),
                              onLongPress: () =>
                                  _selection.handleLongPress(counter.id),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          floatingActionButton: _selection.isActive
              ? SelectionActions(
                  allSelected: _selection.count == counters.length,
                  onSelectAll: () =>
                      _selection.selectAll(counters.map((c) => c.id)),
                  onDeselectAll: _selection.clear,
                  onDelete: _deleteSelected,
                  // No ✕: back leaves selection mode (Nikola).
                  extra: [
                    if (_selection.count == 1)
                      SelectionAction(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit',
                        onPressed: _editSelected,
                      ),
                    SelectionAction(
                      icon: Icons.restart_alt,
                      tooltip: 'Reset',
                      onPressed: _resetSelected,
                    ),
                  ],
                )
              : FloatingActionButton(
                  tooltip: 'New counter',
                  onPressed: _add,
                  child: const Icon(Icons.add),
                ),
        ),
      ),
    );
  }
}

class _CounterCard extends StatelessWidget {
  final Counter counter;
  final int index;
  final bool selectionMode;
  final bool selected;
  final ValueChanged<int> onStep;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _CounterCard({
    required this.counter,
    required this.index,
    required this.selectionMode,
    required this.selected,
    required this.onStep,
    required this.onTap,
    required this.onLongPress,
  });

  /// Rounder than list rows (O5).
  static const _shape = RoundedRectangleBorder(
    borderRadius: BorderRadius.all(Radius.circular(18)),
  );

  /// "0–10", "from 0", "up to 10"; null without limits.
  static String? _limits(Counter c) => switch ((c.min, c.max)) {
        (null, null) => null,
        (final min?, null) => 'from $min',
        (null, final max?) => 'up to $max',
        (final min?, final max?) => '$min–$max',
      };

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final colour = BlockColor.fromName(counter.color);
    final step = counter.step;
    final limits = _limits(counter);
    return SelectableCard(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      color: colour?.fill,
      shape: _shape,
      child: ReorderableRow(
        content: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 0, 14),
          child: Row(
            children: [
              _StepButton(
                icon: Icons.remove,
                label: step == 1 ? null : '−$step',
                tooltip: step == 1
                    ? 'Count down ${counter.name}'
                    : 'Count down ${counter.name} by $step',
                // Off while selecting (a tap there selects instead), and
                // at its lowest.
                onPressed: selectionMode || !counter.canGoDown
                    ? null
                    : () => onStep(-1),
              ),
              Expanded(
                child: Column(
                  children: [
                    Text(
                      counter.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: colors.textSecondary,
                        fontSize: 14,
                      ),
                    ),
                    Text(
                      '${counter.value}',
                      key: Key('counterValue-${counter.id}'),
                      style: TextStyle(
                        color: colors.textPrimary,
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    if (limits != null)
                      Text(
                        limits,
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              ),
              _StepButton(
                icon: Icons.add,
                label: step == 1 ? null : '+$step',
                tooltip: step == 1
                    ? 'Count up ${counter.name}'
                    : 'Count up ${counter.name} by $step',
                onPressed:
                    selectionMode || !counter.canGoUp ? null : () => onStep(1),
              ),
            ],
          ),
        ),
        indicator: ReorderOrSelectIndicator(
          index: index,
          selectionMode: selectionMode,
          selected: selected,
        ),
      ),
    );
  }
}

/// A big round − / + button.
class _StepButton extends StatelessWidget {
  static const size = 64.0;

  final IconData icon;

  /// Shown instead of [icon] for a step above 1 ("+5").
  final String? label;
  final String tooltip;
  final VoidCallback? onPressed;

  const _StepButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final label = this.label;
    return IconButton.filledTonal(
      icon: label == null
          ? Icon(icon, size: 32)
          : FittedBox(
              child: Text(
                label,
                style:
                    const TextStyle(fontSize: 20, fontWeight: FontWeight.w700),
              ),
            ),
      tooltip: tooltip,
      onPressed: onPressed,
      style: IconButton.styleFrom(
        fixedSize: const Size.square(size),
        // The counter plays its own click and vibration, or none if
        // switched off in Settings (U6).
        enableFeedback: false,
      ),
    );
  }
}
