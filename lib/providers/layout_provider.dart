import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/other_tool.dart';

/// Where the pages go (O9): Other's order, saved to `layout.json`.
class LayoutNotifier extends StateNotifier<PageLayout> {
  LayoutNotifier(AppStorage storage) : super(storage.initialLayout) {
    addListener(storage.saveLayout, fireImmediately: false);
  }

  /// Moves [tool] to [index] among Other's tiles (O8).
  void moveInOther(OtherTool tool, int index) {
    if (state.other.indexOf(tool) == index) return;
    state = state.moved(tool, index);
  }
}

final layoutProvider = StateNotifierProvider<LayoutNotifier, PageLayout>(
  (ref) => LayoutNotifier(ref.watch(appStorageProvider)),
);
