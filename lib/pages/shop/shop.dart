import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/shop_item.dart';
import 'package:the_app/providers/shop_provider.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/selection.dart';
import 'package:the_app/widgets/text_input_sheet.dart';

/// Shopping list: "To buy" on top, "Bought" below. Checking an item moves it
/// between the two sections.
class ShopPage extends ConsumerStatefulWidget {
  const ShopPage({super.key});

  @override
  ConsumerState<ShopPage> createState() => _ShopPageState();
}

class _ShopPageState extends ConsumerState<ShopPage> {
  final SelectionController _selection = SelectionController();

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
      onSubmit: _notifier.addItem,
    );
  }

  Future<void> _renameItem(ShopItem item) async {
    final name = await showTextInputSheet(
      context,
      hint: 'Item name',
      initialValue: item.name,
    );
    if (name != null) _notifier.renameItem(item.id, name);
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

  @override
  Widget build(BuildContext context) {
    final items = ref.watch(shopProvider);
    ref.listen(shopProvider, (_, next) {
      _selection.retain(next.map((i) => i.id));
    });

    final toBuy = items.where((i) => !i.bought).toList();
    final bought = items.where((i) => i.bought).toList();

    Widget tile(ShopItem item) => Padding(
          key: ValueKey(item.id),
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: _ShopItemTile(
            item: item,
            selected: _selection.isSelected(item.id),
            onToggleBought: () => _selection.isActive
                ? _selection.toggle(item.id)
                : _notifier.toggleBought(item.id),
            onTap: () =>
                _selection.handleTap(item.id, () => _renameItem(item)),
            onLongPress: () => _selection.handleLongPress(item.id),
          ),
        );

    return SelectionPopScope(
      controller: _selection,
      child: ListenableBuilder(
        listenable: _selection,
        builder: (context, _) => Scaffold(
          appBar: _selection.isActive
              ? SelectionAppBar(
                  count: _selection.count,
                  allSelected: _selection.count == items.length,
                  onClose: _selection.clear,
                  onSelectAll: () =>
                      _selection.selectAll(items.map((i) => i.id)),
                  onDelete: _deleteSelected,
                )
              : AppBar(title: const Text('Shop')),
          body: items.isEmpty
              ? const EmptyState(
                  icon: Icons.shopping_cart_outlined,
                  message: 'Your shopping list is empty',
                )
              : ListView(
                  padding: const EdgeInsets.only(top: 4, bottom: 88),
                  children: [
                    _SectionHeader(title: 'To buy', count: toBuy.length),
                    if (toBuy.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        child: Text(
                          'All done!',
                          style: TextStyle(color: AppColors.textMuted),
                        ),
                      ),
                    ...toBuy.map(tile),
                    if (bought.isNotEmpty) ...[
                      _SectionHeader(title: 'Bought', count: bought.length),
                      ...bought.map(tile),
                    ],
                  ],
                ),
          floatingActionButton: _selection.isActive
              ? null
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Text(
        '${title.toUpperCase()}  ·  $count',
        style: const TextStyle(
          color: AppColors.accent,
          fontSize: 12,
          fontWeight: FontWeight.w600,
          letterSpacing: 1,
        ),
      ),
    );
  }
}

class _ShopItemTile extends StatelessWidget {
  final ShopItem item;
  final bool selected;
  final VoidCallback onToggleBought;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _ShopItemTile({
    required this.item,
    required this.selected,
    required this.onToggleBought,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    return SelectableCard(
      selected: selected,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.all(4),
            child: Checkbox(
              value: item.bought,
              onChanged: (_) => onToggleBought(),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
              child: Text(
                item.name,
                style: TextStyle(
                  fontSize: 16,
                  color: item.bought
                      ? AppColors.textMuted
                      : AppColors.textPrimary,
                  decoration: item.bought ? TextDecoration.lineThrough : null,
                  decorationColor: AppColors.textMuted,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
