import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/providers/shop_provider.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/main_app_bar.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';
import 'package:the_app/widgets/text_input_sheet.dart';

/// Shopping list: "To buy" on top, "Items" (previously bought) below. Tapping
/// an item moves it between the two sections; each section can be reordered.
class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  final SelectionController _selection = SelectionController();

  /// The item added last, scrolled into view above the add sheet.
  String? _addedId;
  final _addedKey = GlobalKey();

  /// About how much of the list the add sheet covers.
  static const _sheetHeight = 80.0;

  @override
  void dispose() {
    _selection.dispose();
    super.dispose();
  }

  ShopNotifier get _notifier => ref.read(shopProvider.notifier);

  void _addItems() {
    showTextInputSheet(
      context,
      hint: 'Add item',
      submitLabel: 'Add',
      keepOpen: true,
      onSubmit: _add,
    );
  }

  /// Adds an item and scrolls to it, so it's seen landing in the list.
  void _add(String name) {
    final id = _notifier.addItem(name);
    if (id == null) return;
    setState(() => _addedId = id);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final row = _addedKey.currentContext;
      if (row != null && mounted) {
        PullDownList.reveal(row, obscuredBottom: _sheetHeight);
      }
    });
  }

  Future<void> _deleteSelected() async {
    final confirmed = await showDeleteConfirmDialog(
      context,
      count: _selection.count,
      singular: 'item',
      plural: 'items',
    );
    if (!confirmed || !mounted) return;
    _notifier.removeItems(_selection.selected);
    _selection.clear();
  }

  Widget _section(List<ShopItem> items, {required bool toBuy}) {
    return SliverReorderableList(
      itemCount: items.length,
      // onReorderItem only exists on newer Flutter than we target.
      // ignore: deprecated_member_use
      onReorder: (oldIndex, newIndex) => _notifier.reorder(
        toBuy: toBuy,
        oldIndex: oldIndex,
        newIndex: newIndex,
      ),
      proxyDecorator: (child, _, __) => Material(
        type: MaterialType.transparency,
        elevation: 6,
        child: child,
      ),
      itemBuilder: (context, index) {
        final item = items[index];
        return Padding(
          key: ValueKey(item.id),
          padding: const EdgeInsets.symmetric(vertical: _ShopItemTile.gap / 2),
          child: _ShopItemTile(
            key: item.id == _addedId ? _addedKey : null,
            item: item,
            index: index,
            selectionMode: _selection.isActive,
            selected: _selection.isSelected(item.id),
            onTap: () => _selection.handleTap(
              item.id,
              () => _notifier.toggle(item.id),
            ),
            onLongPress: () => _selection.handleLongPress(item.id),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(shopProvider);
    ref.listen(shopProvider, (_, next) {
      _selection.retain(next.map((i) => i.id));
    });

    final toBuy = items.where((i) => i.toBuy).toList();
    final stock = items.where((i) => !i.toBuy).toList();

    return SelectionPopScope(
      controller: _selection,
      child: ListenableBuilder(
        listenable: _selection,
        builder: (context, _) => Scaffold(
          appBar: _selection.isActive
              ? SelectionAppBar(count: _selection.count)
              : const MainAppBar(title: 'Shop'),
          body: items.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  message: 'Your shopping list is empty',
                )
              : PullDownList(
                  bottomSpace: SelectionActions.listBottomSpace,
                  // Rows stay built, so a new one can be scrolled to
                  // wherever the list is (shopping lists are short).
                  cacheExtent: 10000,
                  slivers: [
                    _SectionHeader(title: 'To buy', count: toBuy.length),
                    if (toBuy.isEmpty)
                      SliverToBoxAdapter(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          child: Text(
                            'Nothing to buy',
                            style: TextStyle(color: context.colors.textMuted),
                          ),
                        ),
                      ),
                    _section(toBuy, toBuy: true),
                    if (stock.isNotEmpty) ...[
                      _SectionHeader(title: 'Items', count: stock.length),
                      _section(stock, toBuy: false),
                    ],
                  ],
                ),
          floatingActionButton: _selection.isActive
              ? SelectionActions(
                  allSelected: _selection.count == items.length,
                  onSelectAll: () =>
                      _selection.selectAll(items.map((i) => i.id)),
                  onDeselectAll: _selection.clear,
                  onDelete: _deleteSelected,
                  onClose: _selection.clear,
                )
              : FloatingActionButton(
                  // Tabs are kept alive side by side; a shared default hero
                  // tag would clash when a route is pushed.
                  heroTag: null,
                  tooltip: 'Add item',
                  onPressed: _addItems,
                  child: const Icon(Icons.add),
                ),
        ),
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  final int count;

  const _SectionHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        child: Text(
          '${title.toUpperCase()}  ·  $count',
          style: TextStyle(
            color: context.colors.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      ),
    );
  }
}

/// A compact row (S4): exactly one touch target high, so more of the list
/// fits on screen than with note rows, without becoming harder to tap.
class _ShopItemTile extends StatelessWidget {
  /// Vertical space between rows (note rows use 8).
  static const gap = 4.0;

  final ShopItem item;
  final int index;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ShopItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    // One semantic node for the whole row, so screen readers announce it as
    // "Milk, checkbox, not checked" — tapping it does what the checkbox does.
    return MergeSemantics(
      child: SelectableCard(
        selected: selected,
        onTap: onTap,
        onLongPress: onLongPress,
        child: ReorderableRow(
          content: Row(
            children: [
              // Shows the state only: a tap anywhere on the row (with one
              // ripple for the whole row) toggles it.
              IgnorePointer(
                child: Checkbox(
                  value: !item.toBuy,
                  onChanged: (_) => onTap(),
                ),
              ),
              Expanded(
                child: Text(
                  item.name,
                  style: TextStyle(
                    fontSize: 15,
                    color: item.toBuy
                        ? context.colors.textPrimary
                        : context.colors.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          indicator: ReorderOrSelectIndicator(
            index: index,
            selectionMode: selectionMode,
            selected: selected,
          ),
        ),
      ),
    );
  }
}
