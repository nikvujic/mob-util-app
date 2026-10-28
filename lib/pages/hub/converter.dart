import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/core/units.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/widgets/low_handles.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// The unit converter (Round 118): a list of unit pairs, two boxes each;
/// typing in one fills in the other. Nothing is kept once the page is
/// left.
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

  Widget _box(int i, {required bool left}) {
    final pair = _pairs[i];
    return Expanded(
      child: TextField(
        key: Key('unit-$i-${left ? 'left' : 'right'}'),
        controller: left ? _left[i] : _right[i],
        selectionControls: lowHandles,
        keyboardType:
            TextInputType.numberWithOptions(decimal: true, signed: pair.signed),
        inputFormatters: [
          FilteringTextInputFormatter.allow(
              RegExp(pair.signed ? r'[-0-9.,]' : r'[0-9.,]')),
        ],
        decoration: InputDecoration(
          isDense: true,
          suffixText: left ? pair.left : pair.right,
        ),
        onChanged: (_) => _typed(i, left: left),
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
          for (final group in unitGroups) ...[
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                group.title.toUpperCase(),
                style: TextStyle(
                  color: colors.accent,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1,
                ),
              ),
            ),
            for (final _ in group.pairs)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
                child: Row(
                  children: [
                    _box(i, left: true),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Icon(Icons.swap_horiz,
                          size: 20, color: colors.textHint),
                    ),
                    _box(i++, left: false),
                  ],
                ),
              ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }
}
