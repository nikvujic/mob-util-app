import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/counter.dart';
import 'package:the_app/widgets/colour_choice.dart';

/// The sheet to add a counter, or edit [counter] (O5): its name, how much
/// − / + count, its colour and optional limits. Resolves to the options,
/// or null if closed.
Future<CounterOptions?> showCounterSheet(
  BuildContext context, {
  Counter? counter,
}) {
  return showModalBottomSheet<CounterOptions>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _CounterSheet(counter),
  );
}

class _CounterSheet extends StatefulWidget {
  final Counter? counter;

  const _CounterSheet(this.counter);

  @override
  State<_CounterSheet> createState() => _CounterSheetState();
}

class _CounterSheetState extends State<_CounterSheet> {
  late final _name = TextEditingController(text: widget.counter?.name ?? '')
    ..addListener(_changed);
  late final _step = TextEditingController(text: '${widget.counter?.step ?? 1}')
    ..addListener(_changed);
  late final _min = TextEditingController(text: _limit(widget.counter?.min))
    ..addListener(_changed);
  late final _max = TextEditingController(text: _limit(widget.counter?.max))
    ..addListener(_changed);
  late BlockColor? _color = BlockColor.fromName(widget.counter?.color);

  static String _limit(int? v) => v == null ? '' : '$v';

  void _changed() => setState(() {});

  @override
  void dispose() {
    _name.dispose();
    _step.dispose();
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  /// A whole number, or null; [blankOk] lets an empty field mean "none".
  static (int?, String?) _parse(String text, {required bool blankOk}) {
    final t = text.trim();
    if (t.isEmpty) return (null, blankOk ? null : 'Enter a number');
    final v = int.tryParse(t);
    return v == null ? (null, 'A whole number') : (v, null);
  }

  (int?, String?) get _stepValue {
    final (v, error) = _parse(_step.text, blankOk: false);
    if (error != null) return (null, error);
    return v! < 1 ? (null, 'At least 1') : (v, null);
  }

  bool get _valid =>
      _name.text.trim().isNotEmpty &&
      _stepValue.$2 == null &&
      _parse(_min.text, blankOk: true).$2 == null &&
      _parse(_max.text, blankOk: true).$2 == null;

  void _submit() {
    if (!_valid) return;
    Navigator.of(context).pop<CounterOptions>((
      name: _name.text.trim(),
      step: _stepValue.$1!,
      color: _color?.name,
      min: _parse(_min.text, blankOk: true).$1,
      max: _parse(_max.text, blankOk: true).$1,
    ));
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    // Digits and a leading minus (limits may be below 0).
    final whole = [
      FilteringTextInputFormatter.allow(RegExp(r'^-?\d*')),
      LengthLimitingTextInputFormatter(9),
    ];
    const signed = TextInputType.numberWithOptions(signed: true);
    Widget number(
      TextEditingController controller,
      String label,
      String key, {
      String? error,
    }) =>
        Expanded(
          child: TextField(
            key: Key(key),
            controller: controller,
            keyboardType: signed,
            inputFormatters: whole,
            decoration: InputDecoration(
              labelText: label,
              errorText: error,
            ),
          ),
        );

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextField(
                key: const Key('counterName'),
                controller: _name,
                // Typing right away when adding; not when editing.
                autofocus: widget.counter == null,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(labelText: 'Name'),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  number(
                    _step,
                    'Step',
                    'counterStep',
                    error: _stepValue.$2,
                  ),
                  const SizedBox(width: 12),
                  number(
                    _min,
                    'Min',
                    'counterMin',
                    error: _parse(_min.text, blankOk: true).$2,
                  ),
                  const SizedBox(width: 12),
                  number(
                    _max,
                    'Max',
                    'counterMax',
                    error: _parse(_max.text, blankOk: true).$2,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              ColourChoice(
                selected: _color,
                onSelected: (c) => setState(() => _color = c),
              ),
              const SizedBox(height: 8),
              Text(
                'Step is how much − and + count. Min and max stop it there; '
                'leave them empty for no limit.',
                style: TextStyle(color: colors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  key: const Key('counterSubmit'),
                  onPressed: _valid ? _submit : null,
                  child: Text(widget.counter == null ? 'Add' : 'Save'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
