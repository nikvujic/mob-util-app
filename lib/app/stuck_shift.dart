import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/services.dart';

/// Releases a Shift the app wrongly thinks is held (Round 26).
///
/// A tap in a text field while Shift is held extends the selection
/// instead of placing the cursor (Flutter does that for real keyboards).
/// Some phone keyboards send a Shift "down" whose "up" never comes, so
/// every tap in a note selected everything from the start. Before each
/// finger touches the screen, any Shift still "held" is let go of (a
/// Shift-tap from a real keyboard on a phone isn't missed).
void releaseStuckShift() {
  final keyboard = HardwareKeyboard.instance;
  for (final physical in [...keyboard.physicalKeysPressed]) {
    final logical = keyboard.lookUpLayout(physical);
    if (logical != LogicalKeyboardKey.shiftLeft &&
        logical != LogicalKeyboardKey.shiftRight) {
      continue;
    }
    keyboard.handleKeyEvent(
      KeyUpEvent(
        physicalKey: physical,
        logicalKey: logical!,
        timeStamp: Duration.zero,
        synthesized: true,
      ),
    );
  }
}

/// Wraps [handle] (the app's pointer input) so a touch going down first
/// releases a stuck Shift ([releaseStuckShift]), before any text field
/// sees the tap.
ui.PointerDataPacketCallback releasingStuckShift(
  ui.PointerDataPacketCallback handle,
) {
  return (packet) {
    final touchDown = packet.data.any(
      (p) =>
          p.change == ui.PointerChange.down &&
          (p.kind == ui.PointerDeviceKind.touch ||
              p.kind == ui.PointerDeviceKind.stylus),
    );
    if (touchDown && HardwareKeyboard.instance.isShiftPressed) {
      releaseStuckShift();
    }
    handle(packet);
  };
}

/// Puts [releasingStuckShift] in front of the app's pointer input.
void guardAgainstStuckShift() {
  final dispatcher = GestureBinding.instance.platformDispatcher;
  final handle = dispatcher.onPointerDataPacket;
  if (handle == null) return;
  dispatcher.onPointerDataPacket = releasingStuckShift(handle);
}
