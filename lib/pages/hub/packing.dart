import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/packing.dart';
import 'package:the_app/pages/hub/packing_list.dart';
import 'package:the_app/pages/hub/packing_sections.dart';
import 'package:the_app/pages/hub/page_gate.dart';
import 'package:the_app/providers/packing_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';

/// Opens a packing list (view mode), or a new one in edit mode ([isNew]).
void openPackingList(BuildContext context, String id, {bool isNew = false}) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => PageGate(
        page: HubTool.packing,
        child: PackingListPage(listId: id, isNew: isNew),
      ),
    ),
  );
}

/// Packing (Round 94, Nikola): the lists, as cards with their name and
/// how much is packed, in the user's order (the handle moves them). A tap
/// opens one; holding one selects it (to delete several, asked first).
/// + makes a new one, opened in edit mode; Sections opens the sections
/// every list shares.
class PackingPage extends ConsumerStatefulWidget {
  const PackingPage({super.key});

  @override
  ConsumerState<PackingPage> createState() => _PackingPageState();
}

class _PackingPageState extends ConsumerState<PackingPage> {
  final SelectionController _selection = SelectionController();

  PackingNotifier get _notifier => ref.read(packingProvider.notifier);

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  void _add() => openPackingList(context, _notifier.add(), isNew: true);

  /// Asked first, and no Undo after (like Recipes).
  Future<void> _deleteSelected() async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      count: _selection.count,
      singular: 'list',
      plural: 'lists',
    );
    if (!confirmed || !mounted) return;
    _notifier.remove(_selection.selected);
    _selection.clear();
  }

  @override
  Widget build(BuildContext context) {
    final lists = ref.watch(packingProvider.select((b) => b.lists));
    ref.listen(packingProvider, (_, next) {
      _selection.retain(next.lists.map((l) => l.id));
    });

    return SelectionPopScope(
      controller: _selection,
      child: ListenableBuilder(
        listenable: _selection,
        builder: (context, _) => Scaffold(
          appBar: _selection.isActive
              ? SelectionAppBar(count: _selection.count)
              : AppBar(title: Text(HubTool.packing.label)),
          body: lists.isEmpty
              ? const EmptyState(
                  icon: Icons.luggage_outlined,
                  message: 'No packing lists',
                )
              : PullDownList(
                  bottomSpace: SelectionActions.listBottomSpace,
                  slivers: [
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 4),
                      sliver: SliverReorderableList(
                        itemCount: lists.length,
                        // onReorderItem only exists on newer Flutter than
                        // we target.
                        // ignore: deprecated_member_use
                        onReorder: _notifier.reorder,
                        proxyDecorator: (child, _, __) => Material(
                          type: MaterialType.transparency,
                          elevation: 6,
                          child: child,
                        ),
                        itemBuilder: (context, index) {
                          final list = lists[index];
                          return Padding(
                            key: ValueKey(list.id),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 3,
                            ),
                            child: _ListCard(
                              list: list,
                              index: index,
                              selectionMode: _selection.isActive,
                              selected: _selection.isSelected(list.id),
                              onTap: () => _selection.handleTap(
                                list.id,
                                () => openPackingList(context, list.id),
                              ),
                              onLongPress: () =>
                                  _selection.handleLongPress(list.id),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
          floatingActionButton: _selection.isActive
              ? SelectionActions(
                  allSelected: _selection.count == lists.length,
                  onSelectAll: () =>
                      _selection.selectAll(lists.map((l) => l.id)),
                  onDeselectAll: _selection.clear,
                  onDelete: _deleteSelected,
                )
              : BottomActions(
                  actions: [
                    BottomAction(
                      icon: Icons.view_agenda_outlined,
                      tooltip: 'Sections',
                      onPressed: () => openPackingSections(context),
                    ),
                    // Outermost, under the thumb.
                    BottomAction(
                      icon: Icons.add,
                      tooltip: 'New list',
                      primary: true,
                      onPressed: _add,
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

/// "12 of 30 packed", "All 30 packed", or "No items".
String packedLabel(PackingList list) {
  final size = list.items.length;
  final packed = list.packedCount;
  if (size == 0) return 'No items';
  if (packed == size) return 'All $size packed';
  return '$packed of $size packed';
}

class _ListCard extends StatelessWidget {
  final PackingList list;
  final int index;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ListCard({
    required this.list,
    required this.index,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final untitled = list.name.trim().isEmpty;
    final done = list.items.isNotEmpty && list.packedCount == list.items.length;
    return SelectableCard(
      key: Key('packingList-${list.id}'),
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      child: ReorderableRow(
        content: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 0, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                untitled ? 'Untitled' : list.name,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 16,
                  color: untitled ? colors.textSecondary : colors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  if (done) ...[
                    Icon(Icons.check, size: 14, color: colors.accent),
                    const SizedBox(width: 4),
                  ],
                  Text(
                    packedLabel(list),
                    key: Key('packingListProgress-${list.id}'),
                    style: TextStyle(
                      fontSize: 13,
                      color: done ? colors.accent : colors.textSecondary,
                    ),
                  ),
                ],
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
