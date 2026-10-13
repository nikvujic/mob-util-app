import 'package:flutter/material.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/app_section.dart';
import 'package:the_app/providers/password_reset_provider.dart';
import 'package:the_app/widgets/app_dialog.dart';
import 'package:the_app/widgets/confirm_dialog.dart';

/// What came of the reset dialog.
enum ResetChoice {
  /// Closed, nothing done.
  cancel,

  /// Confirmed: reset.
  reset,

  /// Reset tapped instead of held (Round 21): someone not in on it. The
  /// caller greys the reset out for a while.
  tapped,
}

/// How long Reset has to be held when it deletes something (Round 21).
const resetHold = Duration(seconds: 10);

/// Asks to reset a forgotten master password (L7), listing what [plan]
/// deletes. When anything will be deleted, the user has to type
/// [resetConfirmWord] and then **hold** Reset for [resetHold]; a plain tap
/// gives [ResetChoice.tapped] (nothing says so: it's for the owner to
/// know).
Future<ResetChoice> showForgotPasswordDialog(
  BuildContext context,
  PasswordResetPlan plan,
) async {
  final result = await showDialog<ResetChoice>(
    context: context,
    builder: (_) => _ForgotPasswordDialog(plan),
  );
  return result ?? ResetChoice.cancel;
}

class _ForgotPasswordDialog extends StatefulWidget {
  final PasswordResetPlan plan;

  const _ForgotPasswordDialog(this.plan);

  @override
  State<_ForgotPasswordDialog> createState() => _ForgotPasswordDialogState();
}

class _ForgotPasswordDialogState extends State<_ForgotPasswordDialog>
    with SingleTickerProviderStateMixin {
  final _confirm = TextEditingController();

  /// 0 → 1 while Reset is held.
  late final AnimationController _hold =
      AnimationController(vsync: this, duration: resetHold)
        ..addListener(() => setState(() {}))
        ..addStatusListener((status) {
          if (status == AnimationStatus.completed && mounted) {
            Navigator.of(context).pop(ResetChoice.reset);
          }
        });

  @override
  void initState() {
    super.initState();
    _confirm.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _confirm.dispose();
    _hold.dispose();
    super.dispose();
  }

  void _pressed() {
    if (!_deletes) {
      Navigator.of(context).pop(ResetChoice.reset);
      return;
    }
    // Let go: a quick tap (under 0.8 s held) gives it away; a hold let go
    // early just stops.
    final quick = _hold.value * resetHold.inMilliseconds < 800;
    _hold.reset();
    if (quick) Navigator.of(context).pop(ResetChoice.tapped);
  }

  bool get _deletes => widget.plan.deletesAnything;

  bool get _confirmed =>
      !_deletes || _confirm.text.trim().toUpperCase() == resetConfirmWord;

  static String _what(AppSection section, int count) => switch (section) {
        AppSection.notes => countOf(count, 'note', 'notes'),
        AppSection.shop => countOf(count, 'item', 'items'),
        AppSection.planner => countOf(count, 'planner item', 'planner items'),
        AppSection.hub => countOf(count, 'counter', 'counters'),
      };

  List<String> get _lines => [
        if (widget.plan.lockedNotes > 0)
          countOf(widget.plan.lockedNotes, 'locked note', 'locked notes'),
        for (final MapEntry(key: section, value: count)
            in widget.plan.sections.entries)
          if (count > 0)
            '${section.label} (locked section): ${_what(section, count)}',
        for (final MapEntry(key: page, value: count)
            in widget.plan.pages.entries)
          if (count > 0)
            '${page.label} (locked page): ${countOf(count, 'item', 'items')}',
      ];

  @override
  Widget build(BuildContext context) {
    const backups = 'Encrypted backups made with this password still need '
        'it to be restored.';
    return AppDialog(
      title: 'Reset master password?',
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (!_deletes)
            const DialogMessage('Nothing is locked, so nothing will be '
                'deleted. $backups')
          else ...[
            const DialogMessage(
              'The password can\'t be recovered. Resetting it deletes, for '
              'good, everything it locks:',
            ),
            const SizedBox(height: 8),
            for (final line in _lines)
              Padding(
                padding: const EdgeInsets.only(left: 8, top: 4),
                child: Text(
                  '•  $line',
                  style: TextStyle(
                    color: context.colors.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            const SizedBox(height: 12),
            const DialogMessage('Everything else stays. $backups'),
            const SizedBox(height: 16),
            TextField(
              key: const Key('resetConfirm'),
              controller: _confirm,
              autocorrect: false,
              enableSuggestions: false,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(
                labelText: 'Type $resetConfirmWord to confirm',
              ),
            ),
          ],
        ],
      ),
      actions: [
        DialogButton(
          label: 'Cancel',
          onPressed: () => Navigator.of(context).pop(ResetChoice.cancel),
        ),
        // Held, it fills from the left (only once it's being held).
        Listener(
          onPointerDown:
              _confirmed && _deletes ? (_) => _hold.forward(from: 0) : null,
          // A tap's up comes before its onPressed: keep the value for it.
          onPointerUp: (_) => _hold.stop(),
          onPointerCancel: (_) => _hold.reset(),
          child: Stack(
            alignment: Alignment.bottomCenter,
            children: [
              DialogButton(
                key: const Key('resetButton'),
                label: 'Reset',
                primary: true,
                danger: true,
                onPressed: _confirmed ? _pressed : null,
              ),
              if (_hold.value > 0)
                Positioned(
                  left: 0,
                  right: 0,
                  bottom: 0,
                  child: LinearProgressIndicator(
                    key: const Key('resetHold'),
                    value: _hold.value,
                    minHeight: 3,
                    color: context.colors.textPrimary,
                    backgroundColor: Colors.transparent,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
