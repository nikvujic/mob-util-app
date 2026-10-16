import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/models/notify_settings.dart';
import 'package:the_app/providers/reminders_provider.dart';

/// Takes [page]'s shown notifications out of the phone's tray once
/// [child] (that page) is opened (Round 61: not when the app is).
class ClearsShown extends ConsumerStatefulWidget {
  final NotifyPage page;
  final Widget child;

  const ClearsShown({super.key, required this.page, required this.child});

  @override
  ConsumerState<ClearsShown> createState() => _ClearsShownState();
}

class _ClearsShownState extends ConsumerState<ClearsShown> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) ref.read(clearShownProvider)(widget.page);
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
