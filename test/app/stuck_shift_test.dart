import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/app/stuck_shift.dart';

/// A Shift the app wrongly thinks is held (Round 26): taps in a note
/// selected everything from the start instead of placing the cursor.
void main() {
  late TextEditingController text;

  Future<void> pumpField(WidgetTester tester) async {
    text = TextEditingController(text: 'Milk, eggs, bread and some tea');
    addTearDown(text.dispose);
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Center(
          child: SizedBox(width: 400, child: TextField(controller: text)),
        ),
      ),
    ));
    // Focused, the cursor at the start.
    await tester
        .tapAt(tester.getTopLeft(find.byType(TextField)) + const Offset(2, 10));
    await tester.pump(const Duration(milliseconds: 500));
    text.selection = const TextSelection.collapsed(offset: 0);
    await tester.pump();
  }

  Future<void> tapNearEnd(WidgetTester tester) async {
    await tester.tapAt(
        tester.getTopRight(find.byType(TextField)) + const Offset(-40, 10));
    await tester.pump(const Duration(milliseconds: 500));
  }

  /// A finger touching the screen, as the phone sends it.
  ui.PointerDataPacket touch(
          [ui.PointerDeviceKind kind = ui.PointerDeviceKind.touch]) =>
      ui.PointerDataPacket(data: [
        ui.PointerData(change: ui.PointerChange.down, kind: kind),
      ]);

  testWidgets('the bug: with Shift "held", a tap selects from the start',
      (tester) async {
    await pumpField(tester);
    await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    await tapNearEnd(tester);
    expect(text.selection.isCollapsed, isFalse);
    expect(text.selection.start, 0);
    await simulateKeyUpEvent(LogicalKeyboardKey.shiftLeft);
  });

  testWidgets(
      'a finger touching first lets go of it: the tap places the '
      'cursor', (tester) async {
    await pumpField(tester);
    await simulateKeyDownEvent(LogicalKeyboardKey.shiftLeft);
    expect(HardwareKeyboard.instance.isShiftPressed, isTrue);

    var passedOn = 0;
    releasingStuckShift((_) => passedOn++)(touch());
    expect(HardwareKeyboard.instance.isShiftPressed, isFalse);
    expect(passedOn, 1, reason: 'the touch still goes on to the app');

    await tapNearEnd(tester);
    expect(text.selection.isCollapsed, isTrue);
    expect(text.selection.baseOffset, greaterThan(0));
  });

  testWidgets('other keys, and a mouse, are left alone', (tester) async {
    await pumpField(tester);
    await simulateKeyDownEvent(LogicalKeyboardKey.controlLeft);
    await simulateKeyDownEvent(LogicalKeyboardKey.shiftRight);
    var passedOn = 0;
    final handle = releasingStuckShift((_) => passedOn++);

    handle(touch(ui.PointerDeviceKind.mouse));
    expect(HardwareKeyboard.instance.isShiftPressed, isTrue,
        reason: 'a mouse: a real keyboard is likely there too');

    handle(touch());
    expect(HardwareKeyboard.instance.isShiftPressed, isFalse);
    expect(HardwareKeyboard.instance.isControlPressed, isTrue);
    expect(passedOn, 2);
    await simulateKeyUpEvent(LogicalKeyboardKey.controlLeft);
  });
}
