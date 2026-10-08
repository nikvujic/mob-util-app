import 'package:flutter/widgets.dart';

/// Lets widgets inside a screen handle system back before the screen's own
/// back logic runs (e.g. leaving selection mode before "press back again to
/// exit").
///
/// Needed because Flutter calls every back callback on a route when back is
/// blocked; with a registry, exactly one place decides what back does.
class BackHandlers {
  final _handlers = <bool Function()>[];

  void add(bool Function() handler) => _handlers.add(handler);

  void remove(bool Function() handler) => _handlers.remove(handler);

  /// Offers back to the handlers, most recently added first. True if one
  /// of them handled it.
  bool handle() {
    for (final handler in _handlers.reversed.toList()) {
      if (handler()) return true;
    }
    return false;
  }
}

/// Provides [BackHandlers] to the widgets below.
class BackHandlerScope extends InheritedWidget {
  final BackHandlers handlers;

  const BackHandlerScope({
    super.key,
    required this.handlers,
    required super.child,
  });

  static BackHandlers? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BackHandlerScope>()?.handlers;

  @override
  bool updateShouldNotify(BackHandlerScope oldWidget) =>
      handlers != oldWidget.handlers;
}
