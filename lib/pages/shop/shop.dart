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

  /// The select button cycles (Nikola): all of the section where selecting
  /// started → everything (both sections) → nothing.
  SelectionAction _selectStep(List<ShopItem> toBuy, List<ShopItem> stock) {
    final selected = _selection.selected;
    final startedInToBuy = toBuy.any((i) => i.id == selected.first);
    final section = startedInToBuy ? toBuy : stock;
    final all = [...toBuy, ...stock];
    if (all.every((i) => selected.contains(i.id))) {
      return SelectionAction(
        icon: Icons.deselect,
        tooltip: 'Deselect all',
        onPressed: _selection.clear,
      );
    }
    if (section.every((i) => selected.contains(i.id))) {
      return SelectionAction(
        icon: Icons.select_all,
        tooltip: 'Select both lists',
        onPressed: () => _selection.selectAll(all.map((i) => i.id)),
      );
    }
    return SelectionAction(
      icon: Icons.checklist,
      tooltip: startedInToBuy ? 'Select all to buy' : 'Select all items',
      onPressed: () => _selection.selectAll(section.map((i) => i.id)),
    );
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

  /// The amount sheet (S7): big − / + at the bottom, in thumb reach; a
  /// weight can also be typed exactly.
  Future<void> _editAmount(String id) => showModalBottomSheet<void>(
        context: context,
        builder: (_) => _AmountSheet(id: id),
      );

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
            // Amounts change on the list to buy only, outside selection.
            onQuantity: !toBuy || _selection.isActive
                ? null
                : () => _notifier.cycleQuantity(item.id),
            onAmount: !toBuy || _selection.isActive
                ? null
                : () => _editAmount(item.id),
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
                  select: _selectStep(toBuy, stock),
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
/// fits on screen than with note rows, without becoming harder to tap. On
/// the right, before the handle: the amount (S7) and the button that picks
/// its kind.
class _ShopItemTile extends StatelessWidget {
  /// Vertical space between rows (note rows use 8).
  static const gap = 4.0;

  /// Room for the amount and for its kind button.
  static const _amountWidth = 72.0;
  static const _kindWidth = 48.0;

  final ShopItem item;
  final int index;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// none → count → weight; null where it can't change (bought, selecting).
  final VoidCallback? onQuantity;

  /// Opens the amount sheet; null where it can't change.
  final VoidCallback? onAmount;

  const _ShopItemTile({
    super.key,
    required this.item,
    required this.index,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
    this.onQuantity,
    this.onAmount,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final quantity = item.quantity;
    final reserved = (quantity != null ? _amountWidth : 0.0) +
        (onQuantity != null ? _kindWidth : 0.0);
    // One semantic node for the row, so screen readers announce it as
    // "Milk, not checked" — tapping it toggles it. The amount and its
    // button sit on top, outside it, as controls of their own.
    return Stack(
      children: [
        MergeSemantics(
          child: SelectableCard(
            selected: selected,
            onTap: onTap,
            onLongPress: onLongPress,
            child: ReorderableRow(
              content: Row(
                children: [
                  // Shows the state only (U2): a cart while it's to buy, a
                  // tick once it's bought. A tap anywhere on the row (with
                  // one ripple for the whole row) toggles it; screen
                  // readers hear a checkbox.
                  Semantics(
                    checked: !item.toBuy,
                    child: SizedBox.square(
                      dimension: kMinInteractiveDimension,
                      child: Icon(
                        item.toBuy ? Icons.shopping_cart_outlined : Icons.check,
                        key: const Key('shopState'),
                        size: 22,
                        color:
                            item.toBuy ? colors.accent : colors.textSecondary,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      item.name,
                      style: TextStyle(
                        fontSize: 15,
                        color: item.toBuy
                            ? colors.textPrimary
                            : colors.textSecondary,
                      ),
                    ),
                  ),
                  SizedBox(width: reserved),
                ],
              ),
              indicator: ReorderOrSelectIndicator(
                index: index,
                selectionMode: selectionMode,
                selected: selected,
              ),
            ),
          ),
        ),
        if (reserved > 0)
          Positioned(
            top: 0,
            bottom: 0,
            right: ReorderOrSelectIndicator.width,
            child: Row(
              children: [
                if (quantity != null)
                  SizedBox(
                    width: _amountWidth,
                    child: _AmountChip(
                      item,
                      onTap: onAmount,
                      onLongPress: onLongPress,
                    ),
                  ),
                if (onQuantity != null)
                  IconButton(
                    key: const Key('quantityKind'),
                    tooltip: switch (quantity) {
                      null => 'Amount: none',
                      Quantity.count => 'Amount: count',
                      Quantity.weight => 'Amount: weight',
                    },
                    icon: Icon(
                      quantity == Quantity.weight
                          ? Icons.scale_outlined
                          : Icons.numbers,
                      size: 20,
                      color: quantity == null ? colors.textHint : colors.accent,
                    ),
                    onPressed: onQuantity,
                    // Long-pressing anywhere on the row selects it.
                    onLongPress: onLongPress,
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// How much of [item] to get: "×2" or "1.5 kg". Opens the amount sheet
/// when [onTap] is given; otherwise only shows it (the bought list).
class _AmountChip extends StatelessWidget {
  final ShopItem item;
  final VoidCallback? onTap;

  /// Selects the row, as a long-press anywhere on it does.
  final VoidCallback onLongPress;

  const _AmountChip(
    this.item, {
    required this.onTap,
    required this.onLongPress,
  });

  static String text(ShopItem item) => item.quantity == Quantity.weight
      ? formatGrams(item.grams)
      : '×${item.count}';

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final label = Text(
      text(item),
      key: const Key('shopAmount'),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: onTap == null ? colors.textSecondary : colors.textPrimary,
      ),
    );
    // Only shown: touches go to the row underneath.
    if (onTap == null) return IgnorePointer(child: Center(child: label));
    return Semantics(
      button: true,
      label: 'Amount: ${text(item)}',
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        onLongPress: onLongPress,
        borderRadius: BorderRadius.circular(8),
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: colors.textHint),
            ),
            child: label,
          ),
        ),
      ),
    );
  }
}

/// The amount of one item (S7): its kind, and big − / + under the thumb.
/// A weight steps through common amounts; tapping it types an exact one.
/// Changes apply at once.
class _AmountSheet extends ConsumerWidget {
  final String id;

  const _AmountSheet({required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final item = ref.watch(shopProvider).where((i) => i.id == id).firstOrNull;
    if (item == null) return const SizedBox.shrink();
    final shop = ref.read(shopProvider.notifier);
    final colors = context.colors;
    final weight = item.quantity == Quantity.weight;
    // The next amount down / up from [from]; null at the end.
    double? down(ShopItem from) => weight
        ? gramsDown(from.grams)
        : (from.count > 1 ? (from.count - 1).toDouble() : null);
    double? up(ShopItem from) => weight
        ? gramsUp(from.grams)
        : (from.count < ShopNotifier.maxCount
            ? (from.count + 1).toDouble()
            : null);

    /// Steps from the item as it is now, not as last drawn, so quick taps
    /// in one frame all count.
    void stepBy(double? Function(ShopItem) next) {
      final now = ref.read(shopProvider).where((i) => i.id == id).firstOrNull;
      final value = now == null ? null : next(now);
      if (value == null) return;
      weight ? shop.setGrams(id, value) : shop.setCount(id, value.toInt());
    }

    Future<void> typeExact() async {
      final typed = await showTextInputSheet(
        context,
        hint: 'Grams',
        // In grams, without a needless ".0".
        initialValue: item.grams == item.grams.roundToDouble()
            ? '${item.grams.toInt()}'
            : '${item.grams}',
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
      );
      final grams = double.tryParse((typed ?? '').replaceAll(',', '.'));
      if (grams != null) shop.setGrams(id, grams);
    }

    Widget step(
      IconData icon,
      String tooltip,
      double? Function(ShopItem) next,
    ) =>
        IconButton.filledTonal(
          tooltip: tooltip,
          iconSize: 32,
          constraints: const BoxConstraints.tightFor(width: 64, height: 64),
          onPressed: next(item) == null ? null : () => stepBy(next),
          icon: Icon(icon),
        );

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              item.name,
              textAlign: TextAlign.center,
              style: TextStyle(
                color: colors.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<Quantity?>(
              segments: const [
                ButtonSegment(value: null, label: Text('None')),
                ButtonSegment(value: Quantity.count, label: Text('Count')),
                ButtonSegment(value: Quantity.weight, label: Text('Weight')),
              ],
              selected: {item.quantity},
              showSelectedIcon: false,
              onSelectionChanged: (picked) =>
                  shop.setQuantity(id, picked.first),
            ),
            if (item.quantity != null) ...[
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  step(Icons.remove, 'Less', down),
                  Expanded(
                    child: weight
                        // Tap to type an exact weight (Nikola).
                        ? TextButton(
                            key: const Key('typeWeight'),
                            onPressed: typeExact,
                            child: Text(
                              formatGrams(item.grams),
                              style: TextStyle(
                                fontSize: 28,
                                fontWeight: FontWeight.w600,
                                color: colors.textPrimary,
                              ),
                            ),
                          )
                        : Text(
                            '${item.count}',
                            key: const Key('countValue'),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w600,
                              color: colors.textPrimary,
                            ),
                          ),
                  ),
                  step(Icons.add, 'More', up),
                ],
              ),
              if (weight)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    'Tap the weight to type an exact one',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textSecondary, fontSize: 13),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }
}
