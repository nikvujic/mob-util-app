import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/core/theme.dart';

/// Rules in the app's theme that every screen gets.
void main() {
  test(
      'Round 81: a picked chip has no tick, plainly marked instead: a wash '
      'of the accent and edged in it, in every theme', () {
    for (final choice in AppThemeChoice.values) {
      final palette = choice.palette;
      final chips = AppTheme.of(palette).chipTheme;
      expect(chips.showCheckmark, isFalse, reason: choice.name);
      expect(chips.selectedColor, isNot(chips.backgroundColor));
      expect(chips.selectedColor, isNot(palette.cardSelected));
      final side = chips.side! as WidgetStateBorderSide;
      final picked = side.resolve({WidgetState.selected})!;
      final not = side.resolve({})!;
      expect(picked.color, palette.accentForeground ?? palette.accent,
          reason: choice.name);
      expect(picked.width, greaterThan(not.width));
      expect(not.color, palette.divider);
    }
  });

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

  test('bottom messages float, rounded, in the theme\'s colours (U7)', () {
    for (final choice in AppThemeChoice.values) {
      final palette = choice.palette;
      final snack = AppTheme.of(palette).snackBarTheme;
      expect(snack.behavior, SnackBarBehavior.floating, reason: choice.name);
      expect(snack.backgroundColor, palette.card);
      expect(snack.contentTextStyle?.color, palette.textPrimary);
      expect(snack.shape, isA<RoundedRectangleBorder>());
    }
  });
}
