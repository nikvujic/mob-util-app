import 'package:flutter/material.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/widgets/back_handlers.dart';

/// Tracks which items of a list are selected.
///
/// Selection mode is active while at least one item is selected: long-press
/// starts it, and deselecting the last item ends it.
class SelectionController extends ChangeNotifier {
  final Set<String> _selected = {};

  Set<String> get selected => Set.unmodifiable(_selected);
  int get count => _selected.length;
  bool get isActive => _selected.isNotEmpty;
  bool isSelected(String id) => _selected.contains(id);

  void toggle(String id) {
    if (!_selected.remove(id)) _selected.add(id);
    notifyListeners();
  }

  void selectAll(Iterable<String> ids) {
    _selected.addAll(ids);
    notifyListeners();
  }

  void clear() {
    if (_selected.isEmpty) return;
    _selected.clear();
    notifyListeners();
  }

  /// Drops selected ids that no longer exist (e.g. deleted elsewhere).
  void retain(Iterable<String> existingIds) {
    final existing = existingIds.toSet();
    final before = _selected.length;
    _selected.removeWhere((id) => !existing.contains(id));
    if (_selected.length != before) notifyListeners();
  }

  /// Standard tap behaviour: toggles while in selection mode, otherwise runs
  /// [onOpen].
  void handleTap(String id, VoidCallback onOpen) {
    if (isActive) {
      toggle(id);
    } else {
      onOpen();
    }
  }

  /// Standard long-press behaviour: enters selection mode / toggles.
  void handleLongPress(String id) => toggle(id);
}

/// App bar shown while a list is in selection mode.
class SelectionAppBar extends StatelessWidget implements PreferredSizeWidget {
  final int count;
  final bool allSelected;
  final VoidCallback onClose;
  final VoidCallback onSelectAll;
  final VoidCallback onDelete;

  /// Extra actions for the selected items, shown before Delete.
  final List<Widget> actions;

  const SelectionAppBar({
    super.key,
    required this.count,
    required this.allSelected,
    required this.onClose,
    required this.onSelectAll,
    required this.onDelete,
    this.actions = const [],
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  @override
  Widget build(BuildContext context) {
    return AppBar(
      leading: IconButton(
        icon: const Icon(Icons.close),
        tooltip: 'Cancel selection',
        onPressed: onClose,
      ),
      title: Text('$count selected'),
      centerTitle: false,
      actions: [
        IconButton(
          icon: Icon(allSelected ? Icons.deselect : Icons.select_all),
          tooltip: allSelected ? 'Deselect all' : 'Select all',
          onPressed: allSelected ? onClose : onSelectAll,
        ),
        ...actions,
        IconButton(
          icon: const Icon(Icons.delete_outline, color: AppColors.danger),
          tooltip: 'Delete',
          onPressed: onDelete,
        ),
      ],
    );
  }
}

/// Makes system back leave selection mode instead of leaving the screen.
///
/// Inside a [BackHandlerScope] (the home screen) it registers with the
/// screen's back logic; otherwise it uses its own [PopScope]. Either way it
/// only acts while its subtree is the visible tab (see `TickerMode` in
/// `HomeScreen`), so a selection in a hidden tab never takes back.
class SelectionPopScope extends StatefulWidget {
  final SelectionController controller;
  final Widget child;

  const SelectionPopScope({
    super.key,
    required this.controller,
    required this.child,
  });

  @override
  State<SelectionPopScope> createState() => _SelectionPopScopeState();
}

class _SelectionPopScopeState extends State<SelectionPopScope> {
  BackHandlers? _handlers;
  bool _visible = true;

  bool _handleBack() {
    if (!_visible || !widget.controller.isActive) return false;
    widget.controller.clear();
    return true;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final handlers = BackHandlerScope.maybeOf(context);
    if (!identical(handlers, _handlers)) {
      _handlers?.remove(_handleBack);
      _handlers = handlers?..add(_handleBack);
    }
  }

  @override
  void dispose() {
    _handlers?.remove(_handleBack);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // TickerMode.valuesOf only exists on newer Flutter than we target.
    // ignore: deprecated_member_use
    _visible = TickerMode.of(context);
    if (_handlers != null) return widget.child;

    return ListenableBuilder(
      listenable: widget.controller,
      builder: (context, child) => PopScope(
        canPop: !(_visible && widget.controller.isActive),
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) widget.controller.clear();
        },
        child: child!,
      ),
      child: widget.child,
    );
  }
}

/// Card used for list rows that support selection. Highlights itself when
/// [selected], without changing its size, and reports the selection to
/// screen readers.
class SelectableCard extends StatelessWidget {
  final bool selected;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget child;

  const SelectableCard({
    super.key,
    required this.selected,
    required this.child,
    this.onTap,
    this.onLongPress,
  });

  static const _radius = BorderRadius.all(Radius.circular(6));

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected ? true : null,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        decoration: BoxDecoration(
          color: selected ? AppColors.cardSelected : AppColors.card,
          borderRadius: _radius,
        ),
        // Drawn on top so the highlight never changes the row's size.
        foregroundDecoration: BoxDecoration(
          borderRadius: _radius,
          border: Border.all(
            color: selected ? AppColors.accent : Colors.transparent,
          ),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: _radius,
            onTap: onTap,
            onLongPress: onLongPress,
            child: child,
          ),
        ),
      ),
    );
  }
}

/// Trailing control for a reorderable, selectable row: a drag handle
/// normally, a selection indicator while in selection mode.
///
/// Both are hidden from screen readers: reordering is offered to them as
/// "Move up/down" actions by the list, and selection is announced by
/// [SelectableCard].
class ReorderOrSelectIndicator extends StatelessWidget {
  final int index;
  final bool selectionMode;
  final bool selected;

  const ReorderOrSelectIndicator({
    super.key,
    required this.index,
    required this.selectionMode,
    required this.selected,
  });

  @override
  Widget build(BuildContext context) {
    if (selectionMode) {
      return ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Icon(
            selected ? Icons.check_circle : Icons.radio_button_unchecked,
            color: selected ? AppColors.accent : AppColors.textHint,
          ),
        ),
      );
    }
    return ReorderableDragStartListener(
      index: index,
      child: const ExcludeSemantics(
        child: Padding(
          padding: EdgeInsets.all(12),
          child: Icon(Icons.drag_handle, color: AppColors.textHint),
        ),
      ),
    );
  }
}
