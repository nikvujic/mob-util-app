import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/widgets/low_handles.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/markdown.dart';
import 'package:the_app/core/screen.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/recipe.dart';
import 'package:the_app/pages/hub/ingredients.dart';
import 'package:the_app/pages/hub/page_gate.dart';
import 'package:the_app/providers/recipe_read_provider.dart';
import 'package:the_app/providers/recipes_provider.dart';
import 'package:the_app/providers/shop_provider.dart';
import 'package:the_app/widgets/bottom_actions.dart';
import 'package:the_app/widgets/confirm_dialog.dart';
import 'package:the_app/widgets/format_bar.dart';
import 'package:the_app/widgets/markdown_text.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/selection.dart';
import 'package:the_app/widgets/text_input_sheet.dart';

/// One recipe (Round 42). It opens in **view mode**, which keeps the
/// screen on (cooking with the phone set aside): its prep time and type,
/// its ingredients with their quantities, the method as a note shows it;
/// **To Shop** puts the ingredients on Shop's list, **Edit** makes it all
/// editable. In **edit mode** changes are saved as they're made; Undo
/// steps back, Discard changes goes back to how it was when Edit was
/// pressed, Done returns to view mode. A new recipe ([isNew]) opens in
/// edit mode, and is dropped if left with nothing in it.
class RecipePage extends ConsumerStatefulWidget {
  final String recipeId;
  final bool isNew;

  /// Opens in edit mode (a new recipe, or a duplicate).
  final bool startEditing;

  const RecipePage({
    super.key,
    required this.recipeId,
    this.isNew = false,
    bool? startEditing,
  }) : startEditing = startEditing ?? isNew;

  @override
  ConsumerState<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends ConsumerState<RecipePage> {
  static const _saveDelay = Duration(milliseconds: 600);

  /// Typing within this of the last change is the same Undo step.
  static const _burst = Duration(seconds: 1);

  late bool _editing = widget.startEditing;

  /// The recipe as shown (and, in edit mode, as being edited).
  late Recipe _recipe;

  /// As it was when Edit was pressed: Discard changes goes back to it.
  Recipe? _original;

  /// Undo (in edit mode): the recipe before each change.
  final _history = <Recipe>[];
  DateTime? _lastTyped;

  late final TextEditingController _name;
  late final MarkdownEditingController _method;

  final _nameFocus = FocusNode();

  /// Ingredients selected (Round 43: holding one), by position, to remove
  /// several at once.
  final _selected = <int>{};

  /// The keyboard's height when last built: it closing while typing ends
  /// the typing, as in notes.
  double _keyboard = 0;
  final _methodFocus = FocusNode();

  /// Set while undo or discard puts text back in the fields.
  bool _applying = false;

  /// Set once it's gone (deleted, or dropped empty): nothing more saved.
  bool _gone = false;

  Timer? _saveTimer;
  late final AppLifecycleListener _lifecycle;

  bool _formatOpen = false;
  final _formatShown = ValueNotifier(false);
  late final _selectionControls = FormatBarSelectionControls(_formatShown);

  /// Kept from the start: saving on closing comes after `ref` is gone.
  late final RecipesNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = ref.read(recipesProvider.notifier);
    _recipe = _notifier.byId(widget.recipeId) ??
        Recipe(id: widget.recipeId, name: '', createdAt: DateTime.now());
    if (_editing) _original = _recipe;
    _name = TextEditingController(text: _recipe.name);
    _method = MarkdownEditingController(text: _recipe.method);
    _name.addListener(_onText);
    _method.addListener(_onText);
    _methodFocus.addListener(() {
      _method.editing = _methodFocus.hasFocus;
      if (mounted) setState(() {});
    });
    _lifecycle = AppLifecycleListener(onHide: _saveNow);
    // Cooking with the phone set aside: the screen stays on (Round 40).
    KeepScreenOn.hold();
    // Round 53: open a while, it's been read (Pip eats, seen soon after);
    // marked again each minute it stays open.
    _reading = Timer.periodic(const Duration(minutes: 1), (timer) {
      if (timer.tick < recipeReadAfter.inMinutes) return;
      ref.read(recipeReadProvider.notifier).state = ref.read(clockProvider)();
    });
  }

  late final Timer _reading;

  @override
  void dispose() {
    _saveNow();
    _reading.cancel();
    KeepScreenOn.release();
    _lifecycle.dispose();
    _name.dispose();
    _method.dispose();
    _nameFocus.dispose();
    _methodFocus.dispose();
    _formatShown.dispose();
    _viewScroll.dispose();
    super.dispose();
  }

  void _onText() {
    if (_applying) return;
    if (_name.text == _recipe.name && _method.text == _recipe.method) return;
    final now = DateTime.now();
    final last = _lastTyped;
    if (last == null || now.difference(last) > _burst) _history.add(_recipe);
    _lastTyped = now;
    setState(() {
      _recipe = _recipe.copyWith(name: _name.text, method: _method.text);
    });
    _saveTimer?.cancel();
    _saveTimer = Timer(_saveDelay, _saveNow);
  }

  /// A change other than typing: its own Undo step, saved at once.
  void _change(Recipe next) {
    _history.add(_recipe);
    _lastTyped = null;
    setState(() => _recipe = next);
    _saveNow();
  }

  void _saveNow() {
    _saveTimer?.cancel();
    if (_gone) return;
    _notifier.save(_recipe);
  }

  /// Shows [recipe] in the fields (undo, discard).
  void _show(Recipe recipe) {
    _applying = true;
    _name.text = recipe.name;
    _method.text = recipe.method;
    _applying = false;
    setState(() => _recipe = recipe);
  }

  void _undo() {
    if (_history.isEmpty) return;
    _lastTyped = null;
    _show(_history.removeLast());
    _saveNow();
  }

  /// Round 102 (Nikola): switching between view and edit keeps the
  /// scroll: the view list's controller, and a context inside the edit
  /// list to ask how far down it is.
  ScrollController _viewScroll = ScrollController();
  BuildContext? _editInside;
  double _editFrom = 0;

  void _edit() => setState(() {
        _editFrom = _viewScroll.hasClients ? _viewScroll.offset : 0;
        _original = _recipe;
        _history.clear();
        _lastTyped = null;
        _editing = true;
      });

  /// Done: saved, back to view mode; a recipe with nothing in it is
  /// dropped instead, and the page left.
  void _done() {
    FocusManager.instance.primaryFocus?.unfocus();
    if (_recipe.isEmpty) {
      _drop();
      return;
    }
    _saveNow();
    final inside = _editInside;
    final scrolled = inside != null && inside.mounted
        ? PullDownList.scrolledOf(inside)
        : 0.0;
    _viewScroll.dispose();
    _viewScroll = ScrollController(initialScrollOffset: scrolled);
    setState(() {
      _editing = false;
      _formatOpen = false;
      _formatShown.value = false;
    });
  }

  void _drop() {
    _gone = true;
    _saveTimer?.cancel();
    _notifier.remove({widget.recipeId});
    if (ModalRoute.of(context)?.isCurrent ?? false) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _discard() async {
    final original = _original;
    if (original == null) return;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'The recipe goes back to how it was when you pressed Edit.',
      confirmLabel: 'Discard',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    _saveTimer?.cancel();
    _history.clear();
    _lastTyped = null;
    _show(original);
    _notifier.restore(original);
  }

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

  // View mode's actions.

  void _toShop() {
    if (_recipe.ingredients.isEmpty) {
      _toast('No ingredients to add');
      return;
    }
    final done = sendToShop(ref.read, _recipe);
    final parts = [
      if (done.added > 0) '${done.added} added to Shop',
      if (done.putBack > 0) '${done.putBack} put back on the list',
    ];
    _toast(
      parts.isEmpty ? 'All already on the Shop list' : parts.join(', '),
      undo: parts.isEmpty
          ? null
          : () => ref.read(shopProvider.notifier).replaceAll(done.before),
    );
  }

  void _duplicate() {
    _saveNow();
    final id = _notifier.duplicate(widget.recipeId);
    if (id == null) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(
        builder: (_) => PageGate(
          page: HubTool.recipes,
          child: RecipePage(recipeId: id, startEditing: true),
        ),
      ),
    );
  }

  /// The recipe as plain text: name, time and type, ingredients, method.
  static String asText(Recipe recipe) {
    final summary = [
      if (recipe.prepMinutes case final minutes?) prepTimeLabel(minutes),
      if (recipe.type case final type?) type.label,
    ].join(' · ');
    return [
      recipe.name.trim().isEmpty ? 'Untitled' : recipe.name.trim(),
      if (summary.isNotEmpty) summary,
      if (recipe.ingredients.isNotEmpty)
        [
          'Ingredients',
          for (final i in recipe.ingredients)
            i.quantity.isEmpty ? '- ${i.name}' : '- ${i.name}: ${i.quantity}',
        ].join('\n'),
      if (recipe.method.trim().isNotEmpty) 'Method\n${recipe.method.trim()}',
    ].join('\n\n');
  }

  Future<void> _copy() async {
    await Clipboard.setData(ClipboardData(text: asText(_recipe)));
    if (mounted) _toast('Recipe copied');
  }

  void _delete() {
    final messenger = ScaffoldMessenger.of(context);
    final notifier = _notifier;
    final name = _recipe.name.trim().isEmpty ? 'Untitled' : _recipe.name;
    _gone = true;
    _saveTimer?.cancel();
    final removed = notifier.remove({widget.recipeId});
    Navigator.of(context).pop();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text('$name deleted'),
        action: SnackBarAction(
          label: 'Undo',
          onPressed: () => notifier.undoRemove(removed),
        ),
      ));
  }

  /// View mode's other actions (Round 43: at the bottom, in reach, not in
  /// the top bar).
  Future<void> _more() async {
    final choice = await showChoicesSheet(context, null, const [
      (Icons.add_shopping_cart, 'To Shop', 'shop'),
      (Icons.copy_all_outlined, 'Duplicate', 'duplicate'),
      (Icons.content_paste_go_outlined, 'Copy to clipboard', 'copy'),
      (Icons.delete_outline, 'Delete', 'delete'),
    ]);
    if (!mounted) return;
    switch (choice) {
      case 'shop':
        _toShop();
      case 'duplicate':
        _duplicate();
      case 'copy':
        await _copy();
      case 'delete':
        _delete();
    }
  }

  // Edit mode's fields.

  /// Out of the text fields before a sheet or page opens over this one
  /// (Round 43): else closing it gives the field its focus back, and the
  /// page jumps to where its cursor was.
  void _leaveFields() => FocusManager.instance.primaryFocus?.unfocus();

  Future<void> _pickPrepTime() async {
    _leaveFields();
    final picked = await showPrepTimeSheet(context, _recipe.prepMinutes);
    if (picked == null || !mounted) return;
    _change(_recipe.copyWith(prepMinutes: () => picked.minutes));
  }

  Future<void> _pickType() async {
    _leaveFields();
    // Chips, all in reach at once (a list ran off small screens).
    final picked = await showModalBottomSheet<({RecipeType? type})>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Type',
                  style: TextStyle(color: context.colors.textSecondary)),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  for (final type in RecipeType.values)
                    ChoiceChip(
                      key: Key('recipeType-${type.name}'),
                      label: Text(type.label),
                      selected: type == _recipe.type,
                      onSelected: (_) =>
                          Navigator.of(context).pop((type: type)),
                    ),
                  ChoiceChip(
                    key: const Key('recipeType-none'),
                    label: const Text('None'),
                    selected: _recipe.type == null,
                    onSelected: (_) => Navigator.of(context).pop((type: null)),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
    if (picked == null || !mounted) return;
    _change(_recipe.copyWith(type: () => picked.type));
  }

  Future<void> _addIngredients() async {
    _leaveFields();
    final picked = await pickIngredients(
      context,
      already: {
        for (final i in _recipe.ingredients)
          if (i.ingredientId != null) i.ingredientId!,
      },
    );
    if (picked == null || picked.isEmpty || !mounted) return;
    _change(_recipe.copyWith(ingredients: [
      ..._recipe.ingredients,
      for (final i in picked)
        RecipeIngredient(ingredientId: i.id, name: i.name),
    ]));
  }

  /// A tap on an ingredient (Round 43): its options, Quantity then
  /// Delete.
  Future<void> _ingredientOptions(int index) async {
    _leaveFields();
    final ingredient = _recipe.ingredients[index];
    final choice = await showChoicesSheet(context, ingredient.name, const [
      (Icons.scale_outlined, 'Quantity', 'quantity'),
      (Icons.delete_outline, 'Delete', 'delete'),
    ]);
    if (!mounted) return;
    switch (choice) {
      case 'quantity':
        await _editQuantity(index);
      case 'delete':
        _removeIngredients({index});
    }
  }

  /// The quantity picker (Round 43), like Shop's; the recipe changes once,
  /// when it closes.
  Future<void> _editQuantity(int index) async {
    final ingredient = _recipe.ingredients[index];
    final quantity = await showAmountSheet(
      context,
      name: ingredient.name,
      quantity: ingredient.quantity,
    );
    if (!mounted || quantity == null || quantity == ingredient.quantity) {
      return;
    }
    _change(_recipe.copyWith(ingredients: [
      for (var i = 0; i < _recipe.ingredients.length; i++)
        i == index
            ? _recipe.ingredients[i].copyWith(quantity: quantity)
            : _recipe.ingredients[i],
    ]));
  }

  /// Removes the ingredients at [indexes], with Undo.
  void _removeIngredients(Set<int> indexes) {
    if (indexes.isEmpty) return;
    final before = _recipe;
    final names = [
      for (final i in indexes.toList()..sort()) _recipe.ingredients[i].name,
    ];
    _change(_recipe.copyWith(ingredients: [
      for (var i = 0; i < _recipe.ingredients.length; i++)
        if (!indexes.contains(i)) _recipe.ingredients[i],
    ]));
    setState(_selected.clear);
    _toast(
      names.length == 1 ? '${names.single} removed' : '${names.length} removed',
      undo: () {
        if (!mounted || !_editing) return;
        _change(before.copyWith(name: _recipe.name, method: _recipe.method));
      },
    );
  }

  void _toggleSelected(int index) {
    _leaveFields();
    HapticFeedback.selectionClick();
    setState(() {
      if (!_selected.remove(index)) _selected.add(index);
    });
  }

  void _reorderIngredients(int oldIndex, int newIndex) {
    if (newIndex > oldIndex) newIndex--;
    if (oldIndex == newIndex) return;
    final list = [..._recipe.ingredients];
    list.insert(newIndex, list.removeAt(oldIndex));
    _change(_recipe.copyWith(ingredients: list));
  }

  // The method's format bar, as in a note (N17).

  void _format(MdEdit Function(String text, int start, int end) edit) {
    final selection = _method.selection;
    if (!selection.isValid) return;
    final result = edit(_method.text, selection.start, selection.end);
    _method.value = TextEditingValue(
      text: result.text,
      selection: TextSelection(
        baseOffset: result.start,
        extentOffset: result.end,
      ),
    );
  }

  late final List<FormatButton> _formatButtons = [
    FormatButton(Icons.format_list_numbered, 'Numbered list',
        () => _format((t, s, e) => toggleLines(t, s, e, MdLine.numbered))),
    FormatButton(Icons.format_list_bulleted, 'Bulleted list',
        () => _format((t, s, e) => toggleLines(t, s, e, MdLine.bullet))),
    FormatButton(Icons.checklist, 'Checkbox',
        () => _format((t, s, e) => toggleLines(t, s, e, MdLine.checkbox))),
    FormatButton(Icons.format_size, 'Heading', () => _format(cycleHeading)),
    FormatButton(Icons.format_bold, 'Bold',
        () => _format((t, s, e) => toggleWrap(t, s, e, '**'))),
    FormatButton(Icons.format_italic, 'Italic',
        () => _format((t, s, e) => toggleWrap(t, s, e, '*'))),
    FormatButton(Icons.border_color_outlined, 'Highlight',
        () => _format((t, s, e) => toggleWrap(t, s, e, '=='))),
    FormatButton(Icons.format_quote, 'Quote',
        () => _format((t, s, e) => toggleLines(t, s, e, MdLine.quote))),
  ];

  /// Back: out of a field first, then edit mode (as Done), then the page.
  void _onBack() {
    if (_selected.isNotEmpty) {
      setState(_selected.clear);
      return;
    }
    if (_nameFocus.hasFocus || _methodFocus.hasFocus) {
      FocusManager.instance.primaryFocus?.unfocus();
      return;
    }
    _done();
  }

  @override
  Widget build(BuildContext context) {
    // Changed elsewhere (e.g. an ingredient renamed) while viewing.
    if (!_editing && !_gone) {
      final stored = ref.watch(recipesProvider.select(
          (all) => all.where((r) => r.id == widget.recipeId).firstOrNull));
      if (stored != null && !identical(stored, _recipe)) {
        _recipe = stored;
        _applying = true;
        if (_name.text != stored.name) _name.text = stored.name;
        if (_method.text != stored.method) _method.text = stored.method;
        _applying = false;
      }
    }
    // The keyboard closed (its back key) while typing: typing ends, the
    // cursor goes, as in notes (Round 43).
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    if (keyboard == 0 && _keyboard > 0 && _editing) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && MediaQuery.viewInsetsOf(context).bottom == 0) {
          _leaveFields();
        }
      });
    }
    _keyboard = keyboard;
    final name = _recipe.name.trim();
    return PopScope(
      canPop: !_editing,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          if (_recipe.isEmpty && !_gone) {
            _gone = true;
            _notifier.remove({widget.recipeId});
          }
          return;
        }
        _onBack();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            _editing ? 'Edit recipe' : (name.isEmpty ? 'Untitled' : name),
          ),
        ),
        body: _editing ? _editBody(context) : _viewBody(context),
        floatingActionButton: _editing && _selected.isNotEmpty
            ? BottomActions(
                actions: [
                  BottomAction(
                    icon: Icons.delete_outline,
                    tooltip: 'Remove selected',
                    danger: true,
                    onPressed: () => _removeIngredients({..._selected}),
                  ),
                ],
              )
            : _editing
                ? BottomActions(
                    above: [
                      if (_methodFocus.hasFocus)
                        BottomAction(
                          icon: _formatOpen
                              ? Icons.keyboard_hide_outlined
                              : Icons.text_fields,
                          tooltip: _formatOpen ? 'Close formatting' : 'Format',
                          onPressed: () {
                            setState(() => _formatOpen = !_formatOpen);
                            _formatShown.value = _formatOpen;
                          },
                        ),
                    ],
                    bar: _formatOpen && _methodFocus.hasFocus
                        ? FormatBar(buttons: _formatButtons)
                        : null,
                    actions: [
                      BottomAction(
                        icon: Icons.settings_backup_restore,
                        tooltip: 'Discard changes',
                        enabled:
                            _original != null && !_recipe.sameAs(_original!),
                        onPressed: _discard,
                      ),
                      BottomAction(
                        icon: Icons.undo,
                        tooltip: 'Undo',
                        enabled: _history.isNotEmpty,
                        onPressed: _undo,
                      ),
                      // Outermost, under the thumb.
                      BottomAction(
                        icon: Icons.check,
                        tooltip: 'Done',
                        primary: true,
                        onPressed: _done,
                      ),
                    ],
                  )
                : BottomActions(
                    actions: [
                      BottomAction(
                        icon: Icons.more_horiz,
                        tooltip: 'More',
                        onPressed: _more,
                      ),
                      BottomAction(
                        icon: Icons.edit_outlined,
                        tooltip: 'Edit',
                        primary: true,
                        onPressed: _edit,
                      ),
                    ],
                  ),
      ),
    );
  }

  Widget _sectionTitle(String title) => Padding(
        padding: const EdgeInsets.fromLTRB(0, 20, 0, 6),
        child: Text(
          title,
          style: TextStyle(
            color: context.colors.accent,
            fontSize: 12,
            fontWeight: FontWeight.w600,
            letterSpacing: 1,
          ),
        ),
      );

  /// A small box: the prep time, or the type.
  Widget _infoBox(IconData icon, String text, {Key? key}) {
    final colors = context.colors;
    return Container(
      key: key,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colors.card,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: colors.textSecondary),
          const SizedBox(width: 6),
          Text(text, style: TextStyle(color: colors.textPrimary)),
        ],
      ),
    );
  }

  /// The method as a note shows it (Markdown), nothing editable.
  Widget _methodView() {
    final colors = context.colors;
    if (_recipe.method.trim().isEmpty) {
      return Text('Nothing written yet',
          style: TextStyle(color: colors.textMuted));
    }
    return CheckboxBoxes(
      controller: _method,
      child: TextField(
        selectionControls: lowHandles,
        key: const Key('recipeMethodView'),
        controller: _method,
        readOnly: true,
        showCursor: false,
        enableInteractiveSelection: false,
        maxLines: null,
        style: TextStyle(color: colors.textPrimary, fontSize: 16),
        decoration: const InputDecoration(
          border: InputBorder.none,
          contentPadding: EdgeInsets.zero,
          isDense: true,
        ),
      ),
    );
  }

  Widget _viewBody(BuildContext context) {
    final colors = context.colors;
    final ingredients = _recipe.ingredients;
    // No pull-down reach here (Nikola): only in edit mode.
    return ListView(
      key: const Key('recipeView'),
      controller: _viewScroll,
      padding: const EdgeInsets.fromLTRB(
          16, 12, 16, BottomActions.contentClearance + 16),
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _infoBox(
              Icons.timer_outlined,
              _recipe.prepMinutes == null
                  ? 'No time set'
                  : prepTimeLabel(_recipe.prepMinutes!),
              key: const Key('recipePrepTimeView'),
            ),
            if (_recipe.type case final type?)
              _infoBox(Icons.restaurant_outlined, type.label,
                  key: const Key('recipeTypeView')),
          ],
        ),
        _sectionTitle('INGREDIENTS  ·  ${ingredients.length}'),
        if (ingredients.isEmpty)
          Text('None yet', style: TextStyle(color: colors.textMuted)),
        for (final (index, ingredient) in ingredients.indexed)
          Container(
            key: Key('recipeIngredient-$index'),
            padding: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: colors.divider)),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    ingredient.name,
                    style: TextStyle(color: colors.textPrimary, fontSize: 16),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  ingredient.quantity,
                  style: TextStyle(color: colors.textSecondary, fontSize: 16),
                ),
              ],
            ),
          ),
        _sectionTitle('METHOD'),
        _methodView(),
      ],
    );
  }

  Widget _editBody(BuildContext context) {
    final colors = context.colors;
    final ingredients = _recipe.ingredients;
    final clearance = BottomActions.contentClearance +
        BottomActions.aboveClearance +
        (_formatOpen ? FormatBar.height + 8 : 0);
    return PullDownList(
      bottomSpace: clearance,
      initialOffset: _editFrom,
      slivers: [
        // Always built (not lazily, like the rows): how far down it is.
        SliverToBoxAdapter(
          child: Builder(builder: (inside) {
            _editInside = inside;
            return const SizedBox.shrink();
          }),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          sliver: SliverList.list(children: [
            TextField(
              selectionControls: lowHandles,
              key: const Key('recipeName'),
              controller: _name,
              focusNode: _nameFocus,
              // Round 64: no room asked for above it (at the list's top,
              // that pulled into the reach space at every key, which then
              // snapped back: the page bounced).
              scrollPadding: EdgeInsets.fromLTRB(20, 0, 20, clearance + 20),
              autofocus: widget.isNew,
              textCapitalization: TextCapitalization.sentences,
              textInputAction: TextInputAction.done,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w600,
                color: colors.textPrimary,
              ),
              decoration: InputDecoration(
                border: InputBorder.none,
                hintText: 'Name',
                hintStyle: TextStyle(color: colors.textHint),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const Key('recipePrepTime'),
                  onPressed: _pickPrepTime,
                  icon: const Icon(Icons.timer_outlined, size: 18),
                  label: Text(_recipe.prepMinutes == null
                      ? 'Prep time'
                      : prepTimeLabel(_recipe.prepMinutes!)),
                ),
                OutlinedButton.icon(
                  key: const Key('recipeType'),
                  onPressed: _pickType,
                  icon: const Icon(Icons.restaurant_outlined, size: 18),
                  label: Text(_recipe.type?.label ?? 'Type'),
                ),
              ],
            ),
            _sectionTitle('INGREDIENTS  ·  ${ingredients.length}'),
          ]),
        ),
        SliverPadding(
          padding: const EdgeInsets.only(left: 16),
          sliver: SliverReorderableList(
            itemCount: ingredients.length,
            // onReorderItem only exists on newer Flutter than we target.
            // ignore: deprecated_member_use
            onReorder: _reorderIngredients,
            proxyDecorator: (child, _, __) => Material(
              color: colors.card,
              elevation: 6,
              child: child,
            ),
            itemBuilder: (context, index) {
              final ingredient = ingredients[index];
              final selecting = _selected.isNotEmpty;
              return _IngredientRow(
                key: ValueKey('${ingredient.ingredientId ?? ''}-'
                    '${ingredient.name}-$index'),
                index: index,
                ingredient: ingredient,
                selectionMode: selecting,
                selected: _selected.contains(index),
                onTap: selecting
                    ? () => _toggleSelected(index)
                    : () => _ingredientOptions(index),
                onLongPress: () => _toggleSelected(index),
              );
            },
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
          sliver: SliverList.list(children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const Key('recipeAddIngredients'),
                onPressed: _addIngredients,
                icon: const Icon(Icons.add),
                label: const Text('Add'),
              ),
            ),
            _sectionTitle('METHOD'),
            CheckboxTaps(
              controller: _method,
              child: CheckboxBoxes(
                controller: _method,
                child: TextField(
                  key: const Key('recipeMethod'),
                  controller: _method,
                  focusNode: _methodFocus,
                  selectionControls: _selectionControls,
                  keyboardType: TextInputType.multiline,
                  textCapitalization: TextCapitalization.sentences,
                  maxLines: null,
                  magnifierConfiguration: TextMagnifierConfiguration.disabled,
                  scrollPadding:
                      EdgeInsets.fromLTRB(20, 20, 20, clearance + 20),
                  inputFormatters: const [MarkdownListFormatter()],
                  style: TextStyle(color: colors.textPrimary, fontSize: 16),
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'How it’s made…',
                    hintStyle: TextStyle(color: colors.textHint),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
            ),
          ]),
        ),
      ],
    );
  }
}

/// An ingredient in edit mode: plain, no background: its name, its
/// quantity if it has one (quiet, not a button: Round 43), the handle. A
/// tap gives its options; holding selects it.
class _IngredientRow extends StatelessWidget {
  final int index;
  final RecipeIngredient ingredient;
  final bool selectionMode;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _IngredientRow({
    super.key,
    required this.index,
    required this.ingredient,
    required this.selectionMode,
    required this.selected,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Semantics(
      selected: selectionMode ? selected : null,
      child: Material(
        color: selected ? colors.cardSelected : Colors.transparent,
        borderRadius: BorderRadius.circular(6),
        child: InkWell(
          key: Key('recipeIngredientRow-$index'),
          borderRadius: BorderRadius.circular(6),
          onTap: onTap,
          onLongPress: onLongPress,
          child: ReorderableRow(
            content: Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      ingredient.name,
                      style: TextStyle(color: colors.textPrimary, fontSize: 16),
                    ),
                  ),
                  if (ingredient.quantity.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.only(left: 12),
                      child: Text(
                        ingredient.quantity,
                        key: Key('recipeQuantity-$index'),
                        style: TextStyle(
                          color: colors.textSecondary,
                          fontSize: 14,
                        ),
                      ),
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
        ),
      ),
    );
  }
}

/// A small sheet of choices at the bottom (one-handed); the value picked,
/// or null.
Future<String?> showChoicesSheet(
  BuildContext context,
  String? title,
  List<(IconData, String, String)> choices,
) =>
    showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (title != null)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: context.colors.textSecondary,
                    fontSize: 14,
                  ),
                ),
              )
            else
              const SizedBox(height: 8),
            for (final (icon, label, value) in choices)
              ListTile(
                key: Key('choice-$value'),
                leading: Icon(icon),
                title: Text(label),
                onTap: () => Navigator.of(context).pop(value),
              ),
          ],
        ),
      ),
    );

/// The quantity picker (Round 43): Shop's kinds (a count, a weight)
/// and spoons, small and big; big − / + at the bottom, a weight typed
/// exactly at a tap; or free text ("1-2", Round 70). Resolves to the
/// quantity as text when closed.
Future<String?> showAmountSheet(
  BuildContext context, {
  required String name,
  required String quantity,
}) async {
  final picked = ValueNotifier<Amount?>(readAmount(quantity));
  // Text the picker doesn't know is typed text.
  final typed = ValueNotifier(picked.value == null ? quantity.trim() : '');
  await showModalBottomSheet<void>(
    context: context,
    // Room for the keyboard when typing.
    isScrollControlled: true,
    builder: (_) => _AmountSheet(name: name, typed: typed, picked: picked),
  );
  final amount = picked.value;
  final text = typed.value.trim();
  picked.dispose();
  typed.dispose();
  return amount == null ? text : amountText(amount);
}

class _AmountSheet extends StatelessWidget {
  final String name;

  /// The typed quantity, while [picked] is null (Text).
  final ValueNotifier<String> typed;
  final ValueNotifier<Amount?> picked;

  const _AmountSheet({
    required this.name,
    required this.typed,
    required this.picked,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ValueListenableBuilder(
      valueListenable: picked,
      builder: (context, amount, _) {
        final kind = amount?.kind;
        Widget step(IconData icon, String tooltip, double? next) =>
            IconButton.filledTonal(
              tooltip: tooltip,
              iconSize: 32,
              constraints: const BoxConstraints.tightFor(width: 64, height: 64),
              onPressed: next == null
                  ? null
                  : () => picked.value = (kind: kind!, value: next),
              icon: Icon(icon),
            );

        Future<void> typeExact() async {
          final typedGrams = await showTextInputSheet(
            context,
            hint: 'Grams',
            initialValue: amount!.value == amount.value.roundToDouble()
                ? '${amount.value.toInt()}'
                : '${amount.value}',
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
          );
          final grams =
              double.tryParse((typedGrams ?? '').replaceAll(',', '.'));
          if (grams != null && grams > 0) {
            picked.value = (kind: AmountKind.weight, value: grams);
          }
        }

        return SafeArea(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
                16, 16, 16, 16 + MediaQuery.viewInsetsOf(context).bottom),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  name,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: colors.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final option in AmountKind.values)
                      ChoiceChip(
                        key: Key('amount-${option.name}'),
                        label: Text(option.label),
                        selected: option == kind,
                        onSelected: (_) => picked.value = option == kind
                            ? amount
                            : (kind: option, value: startOf(option)),
                      ),
                    ChoiceChip(
                      key: const Key('amount-text'),
                      label: const Text('Text'),
                      selected: amount == null,
                      onSelected: (_) {
                        if (amount == null) return;
                        // Starts from the amount picked, to edit.
                        typed.value = amountText(amount);
                        picked.value = null;
                      },
                    ),
                  ],
                ),
                if (amount == null)
                  Padding(
                    padding: const EdgeInsets.only(top: 20),
                    child: _TypedAmount(typed),
                  ),
                if (amount != null && kind != AmountKind.none) ...[
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      step(Icons.remove, 'Less', amountDown(amount)),
                      Expanded(
                        child: kind == AmountKind.weight
                            // Tap to type an exact weight, as in Shop.
                            ? TextButton(
                                key: const Key('amountTypeWeight'),
                                onPressed: typeExact,
                                child: Text(
                                  amountText(amount),
                                  style: TextStyle(
                                    fontSize: 28,
                                    fontWeight: FontWeight.w600,
                                    color: colors.textPrimary,
                                  ),
                                ),
                              )
                            : Text(
                                amountText(amount),
                                key: const Key('amountValue'),
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 28,
                                  fontWeight: FontWeight.w600,
                                  color: colors.textPrimary,
                                ),
                              ),
                      ),
                      step(Icons.add, 'More', amountUp(amount)),
                    ],
                  ),
                ],
              ],
            ),
          ),
        );
      },
    );
  }
}

/// The quantity typed as text (Round 70), into [typed].
class _TypedAmount extends StatefulWidget {
  final ValueNotifier<String> typed;

  const _TypedAmount(this.typed);

  @override
  State<_TypedAmount> createState() => _TypedAmountState();
}

class _TypedAmountState extends State<_TypedAmount> {
  late final _controller = TextEditingController(text: widget.typed.value);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextField(
        selectionControls: lowHandles,
        key: const Key('amountTypedText'),
        controller: _controller,
        autofocus: true,
        maxLength: 30,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20),
        decoration: const InputDecoration(
          hintText: 'e.g. 1-2, a pinch',
          counterText: '',
        ),
        onChanged: (text) => widget.typed.value = text,
        onSubmitted: (_) => Navigator.of(context).pop(),
      );
}

/// The prep time picker (Round 41): − / + by 5 minutes, or a common time
/// at a tap; Clear for none. Null if dismissed.
Future<({int? minutes})?> showPrepTimeSheet(
  BuildContext context,
  int? current,
) {
  const common = [10, 15, 20, 30, 45, 60, 90, 120];
  var minutes = current ?? 30;
  return showModalBottomSheet<({int? minutes})>(
    context: context,
    builder: (context) => StatefulBuilder(
      builder: (context, setState) {
        final colors = context.colors;
        void step(int by) =>
            setState(() => minutes = (minutes + by).clamp(5, 24 * 60));
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Prep time',
                    style: TextStyle(color: colors.textSecondary)),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton.filledTonal(
                      key: const Key('prepTimeLess'),
                      tooltip: '5 minutes less',
                      onPressed: minutes > 5 ? () => step(-5) : null,
                      icon: const Icon(Icons.remove),
                    ),
                    SizedBox(
                      width: 140,
                      child: Text(
                        prepTimeLabel(minutes),
                        key: const Key('prepTimeValue'),
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: colors.textPrimary,
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    IconButton.filledTonal(
                      key: const Key('prepTimeMore'),
                      tooltip: '5 minutes more',
                      onPressed: () => step(5),
                      icon: const Icon(Icons.add),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 4,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final value in common)
                      ChoiceChip(
                        key: Key('prepTime-$value'),
                        label: Text(prepTimeLabel(value)),
                        selected: minutes == value,
                        onSelected: (_) => setState(() => minutes = value),
                      ),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    TextButton(
                      key: const Key('prepTimeClear'),
                      onPressed: () =>
                          Navigator.of(context).pop((minutes: null)),
                      child: const Text('No time'),
                    ),
                    const Spacer(),
                    FilledButton(
                      key: const Key('prepTimeSet'),
                      onPressed: () =>
                          Navigator.of(context).pop((minutes: minutes)),
                      child: const Text('Set'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    ),
  );
}
