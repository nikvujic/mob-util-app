import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/food.dart';
import 'package:the_app/providers/food_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/empty_state.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';
import 'package:the_app/widgets/text_input_sheet.dart';

/// The foods (Round 46), by name: what's logged grows it, + adds more. A
/// tap gives Rename, Tags (dairy, gluten… for the statistics by kind) and
/// Delete (with Undo; meals keep the name).
class FoodsPage extends ConsumerStatefulWidget {
  const FoodsPage({super.key});

  @override
  ConsumerState<FoodsPage> createState() => _FoodsPageState();
}

class _FoodsPageState extends ConsumerState<FoodsPage> {
  FoodNotifier get _notifier => ref.read(foodProvider.notifier);

  void _toast(String message, {VoidCallback? undo}) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(message),
        action: undo == null
            ? null
            : SnackBarAction(label: 'Undo', onPressed: undo),
      ));
  }

  void _add() => showTextInputSheet(
        context,
        hint: 'Add a food',
        submitLabel: 'Add',
        keepOpen: true,
        onSubmit: (name) => _notifier.foodNamed(name),
      );

  Future<void> _menu(Food food) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                food.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: context.colors.textSecondary,
                  fontSize: 14,
                ),
              ),
            ),
            for (final (icon, label, value) in [
              (Icons.edit_outlined, 'Rename', 'rename'),
              (Icons.sell_outlined, 'Tags', 'tags'),
              (Icons.delete_outline, 'Delete', 'delete'),
            ])
              ListTile(
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.of(context).pop(value),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    switch (choice) {
      case 'rename':
        await showTextInputSheet(
          context,
          hint: 'Food',
          initialValue: food.name,
          onSubmit: (name) {
            if (!_notifier.renameFood(food.id, name) &&
                name.trim().isNotEmpty &&
                name.trim() != food.name) {
              _toast('There is a food called that already');
            }
          },
        );
      case 'tags':
        await showModalBottomSheet<void>(
          context: context,
          builder: (_) => _TagsSheet(foodId: food.id),
        );
      case 'delete':
        final before = _notifier.deleteFood(food.id);
        _toast('${food.name} deleted',
            undo: () => _notifier.replaceAll(before));
    }
  }

  @override
  Widget build(BuildContext context) {
    final foods = [...ref.watch(foodProvider).foods]
      ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    final colors = context.colors;
    return Scaffold(
      appBar: AppBar(title: const Text('Foods')),
      body: foods.isEmpty
          ? const EmptyState(icon: Icons.restaurant, message: 'No foods yet')
          : PullDownList(
              bottomSpace: BottomActions.contentClearance,
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(top: 4),
                  sliver: SliverList.list(
                    children: [
                      for (final food in foods)
                        Padding(
                          key: ValueKey(food.id),
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 2,
                          ),
                          child: SelectableCard(
                            selected: false,
                            onTap: () => _menu(food),
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(
                                minHeight: kMinInteractiveDimension,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 10,
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      food.name,
                                      style: TextStyle(
                                        color: colors.textPrimary,
                                        fontSize: 15,
                                      ),
                                    ),
                                    if (food.tags.isNotEmpty)
                                      Text(
                                        [
                                          for (final t in FoodTag.values)
                                            if (food.tags.contains(t)) t.label,
                                        ].join(', '),
                                        style: TextStyle(
                                          color: colors.textMuted,
                                          fontSize: 12,
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
      floatingActionButton: BottomActions(
        actions: [
          BottomAction(
            icon: Icons.add,
            tooltip: 'Add a food',
            primary: true,
            onPressed: _add,
          ),
        ],
      ),
    );
  }
}

/// A food's tags, each a chip turned on and off (saved at once).
class _TagsSheet extends ConsumerWidget {
  final String foodId;

  const _TagsSheet({required this.foodId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final food = ref.watch(foodProvider).foodById(foodId);
    if (food == null) return const SizedBox.shrink();
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${food.name}: tags',
              style: TextStyle(color: context.colors.textSecondary),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final tag in FoodTag.values)
                  FilterChip(
                    key: Key('foodTag-${tag.name}'),
                    label: Text(tag.label),
                    selected: food.tags.contains(tag),
                    onSelected: (on) => ref.read(foodProvider.notifier).setTags(
                          food.id,
                          on
                              ? {...food.tags, tag}
                              : ({...food.tags}..remove(tag)),
                        ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
