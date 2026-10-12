import 'dart:async';

import 'package:flutter/widgets.dart';

/// Builds again every [every] (e.g. so doses whose time has come turn
/// red with nothing else changing). Its timer goes with it.
class Ticking extends StatefulWidget {
  final Duration every;
  final WidgetBuilder builder;

  const Ticking({
    super.key,
    this.every = const Duration(seconds: 30),
    required this.builder,
  });

  @override
  State<Ticking> createState() => _TickingState();
}

class _TickingState extends State<Ticking> {
  late final Timer _timer =
      Timer.periodic(widget.every, (_) => setState(() {}));

  @override
  void initState() {
    super.initState();
    _timer; // start
  }

  @override
  void dispose() {
    _timer.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.builder(context);
}
