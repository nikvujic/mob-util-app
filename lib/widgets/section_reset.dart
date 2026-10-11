import 'package:flutter/widgets.dart';

/// Tells what's below it that its section was switched to or away from
/// (the home screen fires [signal] for both, G13 / G18): lists go back to
/// their normal top, selection mode ends, the planner goes back to today.
class SectionReset extends InheritedWidget {
  final Listenable signal;

  const SectionReset({super.key, required this.signal, required super.child});

  static Listenable? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SectionReset>()?.signal;

  @override
  bool updateShouldNotify(SectionReset old) => signal != old.signal;
}
