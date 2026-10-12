import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/theme.dart';

/// Rules in the app's theme that every screen gets.
void main() {
  test('no button fades between states, in any theme (U8)', () {
    for (final choice in AppThemeChoice.values) {
      final theme = AppTheme.of(choice.palette);
      final styles = {
        'filled': theme.filledButtonTheme.style,
        'elevated': theme.elevatedButtonTheme.style,
        'outlined': theme.outlinedButtonTheme.style,
        'text': theme.textButtonTheme.style,
        'icon': theme.iconButtonTheme.style,
      };
      for (final MapEntry(key: kind, value: style) in styles.entries) {
        expect(style?.animationDuration, Duration.zero,
            reason: '${choice.name}: $kind buttons');
      }
    }
  });
}
