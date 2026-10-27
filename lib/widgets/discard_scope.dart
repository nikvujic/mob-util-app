import 'package:flutter/material.dart';
import 'package:the_app/widgets/confirm_dialog.dart';

/// A page saved as it's typed (Round 91, as a note): with
/// [changed], back asks **Discard** or **Save**. Save (or Back on the
/// dialog) keeps it as it is; Discard calls [onDiscard] (it puts back how
/// it was, or removes a new one) and leaves; a tap outside stays.
/// Unchanged, back just leaves. Leaving any other way (the app closed,
/// a lock) keeps what was typed, as ever.
///
/// [handleBack], if given, goes first: true when it dealt with back
/// itself (e.g. closing an open list), so nothing is asked.
class DiscardScope extends StatefulWidget {
  final bool changed;

  /// A new one: "Save new …?", and Discard removes it.
  final bool isNew;

  /// What it is, for the question: "subscription", "date", "meal".
  final String what;
  final VoidCallback onDiscard;
  final bool Function()? handleBack;
  final Widget child;

  const DiscardScope({
    super.key,
    required this.changed,
    required this.isNew,
    required this.what,
    required this.onDiscard,
    this.handleBack,
    required this.child,
  });

  @override
  State<DiscardScope> createState() => _DiscardScopeState();
}

class _DiscardScopeState extends State<DiscardScope> {
  bool _asking = false;

  Future<void> _back() async {
    if (widget.handleBack?.call() ?? false) return;
    if (!widget.changed) {
      Navigator.of(context).pop();
      return;
    }
    if (_asking) return;
    _asking = true;
    final save = await showSaveChangesDialog(
      context,
      title: widget.isNew ? 'Save new ${widget.what}?' : 'Save changes?',
      message: widget.isNew
          ? 'New ${widget.what}s are saved automatically. Discard deletes '
              'this ${widget.what}.'
          : 'Your changes are saved automatically. Discard puts the '
              '${widget.what} back the way it was.',
    );
    _asking = false;
    if (!mounted || save == null) return; // tapped outside: stay
    if (!save) widget.onDiscard();
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) => PopScope(
        canPop: false,
        onPopInvokedWithResult: (didPop, _) {
          if (!didPop) _back();
        },
        child: widget.child,
      );
}
