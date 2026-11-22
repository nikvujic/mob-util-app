import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/core/units.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/widgets/low_handles.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// The unit converter (Round 118): a list of unit pairs, two boxes each;
/// typing in one fills in the other. Nothing is kept once the page is
/// left. Round 153: each group a card with
/// its icon; each unit a tile, its name over a big number and its symbol;
/// the one being typed in lifts in the accent.
class ConverterPage extends StatefulWidget {
  const ConverterPage({super.key});

  @override
  State<ConverterPage> createState() => _ConverterPageState();
}

class _ConverterPageState extends State<ConverterPage> {
  late final _pairs = [for (final g in unitGroups) ...g.pairs];
  late final _left = [for (final _ in _pairs) TextEditingController()];
  late final _right = [for (final _ in _pairs) TextEditingController()];

  @override
  void dispose() {
    for (final c in [..._left, ..._right]) {
      c.dispose();
    }
    super.dispose();
  }

  /// Typed in one box of pair [i]: the other shows it converted (or
  /// nothing, for nothing or not a number).
  void _typed(int i, {required bool left}) {
    final pair = _pairs[i];
    final from = left ? _left[i] : _right[i];
    final to = left ? _right[i] : _left[i];
    final value = parseAmount(from.text);
    to.text = value == null
        ? ''
        : formatAmount(left ? pair.toRight(value) : pair.toLeft(value));
  }

  /// Each group's icon.
  static IconData _iconOf(String title) => switch (title) {
        'Temperature' => Icons.thermostat_rounded,
        'Length' => Icons.straighten_rounded,
        'Weight' => Icons.scale_rounded,
        'Volume' => Icons.water_drop_rounded,
        'Speed' => Icons.speed_rounded,
        'Cooking' => Icons.restaurant_rounded,
        _ => Icons.swap_horiz_rounded,
      };

  Widget _pairRow(int i) {
    final pair = _pairs[i];
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
      child: Row(
        children: [
          Expanded(
            child: _UnitTile(
              fieldKey: Key('unit-$i-left'),
              controller: _left[i],
              name: pair.leftName,
              symbol: pair.left,
              signed: pair.signed,
              onChanged: () => _typed(i, left: true),
            ),
          ),
          const _SwapMark(),
          Expanded(
            child: _UnitTile(
              fieldKey: Key('unit-$i-right'),
              controller: _right[i],
              name: pair.rightName,
              symbol: pair.right,
              signed: pair.signed,
              onChanged: () => _typed(i, left: false),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    var i = 0;
    return Scaffold(
      appBar: AppBar(title: Text(HubTool.converter.label)),
      body: PullDownList.children(
        children: [
          const SizedBox(height: 8),
          for (final group in unitGroups)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 12, 6),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: colors.card,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: colors.divider),
                ),
                child: Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 8),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(14, 0, 14, 4),
                        child: Row(
                          children: [
                            Container(
                              width: 30,
                              height: 30,
                              decoration: BoxDecoration(
                                color: colors.accent.withValues(alpha: 0.14),
                                shape: BoxShape.circle,
                              ),
                              child: Icon(_iconOf(group.title),
                                  size: 17, color: colors.accent),
                            ),
                            const SizedBox(width: 10),
                            Text(
                              group.title,
                              style: TextStyle(
                                color: colors.textPrimary,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      for (final _ in group.pairs) _pairRow(i++),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}

/// The mark between a pair's two tiles: it goes both ways.
class _SwapMark extends StatelessWidget {
  const _SwapMark();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: ExcludeSemantics(
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.12),
            shape: BoxShape.circle,
          ),
          child: Icon(Icons.sync_alt_rounded, size: 16, color: colors.accent),
        ),
      ),
    );
  }
}

/// One unit of a pair: its name, the number (big), its symbol. Being
/// typed in, it lifts: an accent border and a soft glow. A tap anywhere
/// on it types in it.
class _UnitTile extends StatefulWidget {
  final Key fieldKey;
  final TextEditingController controller;
  final String name;
  final String symbol;
  final bool signed;
  final VoidCallback onChanged;

  const _UnitTile({
    required this.fieldKey,
    required this.controller,
    required this.name,
    required this.symbol,
    required this.signed,
    required this.onChanged,
  });

  @override
  State<_UnitTile> createState() => _UnitTileState();
}

class _UnitTileState extends State<_UnitTile> {
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final on = _focus.hasFocus;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: _focus.requestFocus,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        curve: Curves.easeOut,
        padding: const EdgeInsets.fromLTRB(12, 9, 12, 8),
        decoration: BoxDecoration(
          color: on ? colors.cardSelected : colors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: on ? colors.accent : colors.divider,
            width: on ? 1.6 : 1,
          ),
          boxShadow: [
            if (on)
              BoxShadow(
                color: colors.accent.withValues(alpha: 0.22),
                blurRadius: 12,
                spreadRadius: 0.5,
              ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: on ? colors.accent : colors.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Expanded(
                  child: TextField(
                    key: widget.fieldKey,
                    controller: widget.controller,
                    focusNode: _focus,
                    selectionControls: lowHandles,
                    keyboardType: TextInputType.numberWithOptions(
                        decimal: true, signed: widget.signed),
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(
                          RegExp(widget.signed ? r'[-0-9.,]' : r'[0-9.,]')),
                      // Round 154: two decimals at most.
                      TextInputFormatter.withFunction((old, typed) =>
                          withinDecimals(typed.text) ? typed : old),
                    ],
                    style: TextStyle(
                      color: colors.textPrimary,
                      fontSize: 22,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                    cursorColor: colors.accent,
                    decoration: InputDecoration(
                      isCollapsed: true,
                      border: InputBorder.none,
                      enabledBorder: InputBorder.none,
                      focusedBorder: InputBorder.none,
                      hintText: '0',
                      hintStyle: TextStyle(
                        color: colors.textHint,
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onChanged: (_) => widget.onChanged(),
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  widget.symbol,
                  style: TextStyle(
                    color: on ? colors.accent : colors.textMuted,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
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
