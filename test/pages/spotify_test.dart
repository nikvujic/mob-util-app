import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/morning_music.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/preferences_provider.dart';

import '../helpers.dart';

/// Round 93: Spotify in the morning, a Hub page of settings: on
/// or off, a time, the days and a volume; the phone's alarm follows them.
void main() {
  /// Tuesday, 20 October 2026, 12:00.
  final now = DateTime(2026, 10, 20, 12);

  group('MorningMusic', () {
    test('off by default, weekdays at 07:00, 30%', () {
      const m = MorningMusic.initial;
      expect((m.on, m.minutes, m.volume), (false, 420, 30));
      expect(m.weekdays, {1, 2, 3, 4, 5});
      expect(m.nextAfter(now), isNull, reason: 'off');
    });

    test('the next time: its time on one of its days, after now', () {
      final on = const MorningMusic().copyWith(on: true);
      // Tuesday noon: Wednesday 07:00.
      expect(on.nextAfter(now), DateTime(2026, 10, 21, 7));
      // Before 07:00 on a weekday: that day.
      expect(on.nextAfter(DateTime(2026, 10, 20, 6, 59)),
          DateTime(2026, 10, 20, 7));
      // At 07:00 exactly: the next day.
      expect(
          on.nextAfter(DateTime(2026, 10, 20, 7)), DateTime(2026, 10, 21, 7));
      // Friday noon, weekdays only: Monday.
      expect(
          on.nextAfter(DateTime(2026, 10, 23, 12)), DateTime(2026, 10, 26, 7));
      // Sundays only, from a Sunday after its time: a week on.
      expect(on.copyWith(weekdays: {7}).nextAfter(DateTime(2026, 10, 25, 8)),
          DateTime(2026, 11, 1, 7));
      expect(on.copyWith(weekdays: {}).nextAfter(now), isNull);
    });

    test('kept in the preferences; only when not as by default', () {
      expect(const Preferences().toJson(), isNot(contains('morningMusic')));
      final m = const MorningMusic(
          on: true, minutes: 6 * 60 + 45, weekdays: {6, 7, 1}, volume: 55);
      final json = Preferences(morningMusic: m).toJson();
      expect(json['morningMusic'], {
        'on': true,
        'minutes': 405,
        'weekdays': [1, 6, 7],
        'volume': 55,
      });
      expect(Preferences.fromJson(json).morningMusic, m);
      // Odd values: clamped or dropped.
      expect(
          MorningMusic.fromJson(const {
            'minutes': 5000,
            'weekdays': [0, 3, 9],
            'volume': 140,
          }),
          const MorningMusic(minutes: 1439, weekdays: {3}, volume: 100));
    });

    test('a page of its own: no lock, nothing to clear', () {
      expect(HubTool.spotify.label, 'Spotify');
      expect(HubTool.spotify.lockable, isFalse);
      expect(HubTool.spotify.clearable, isFalse);
    });
  });

  group('its page', () {
    late ProviderContainer container;
    late FakeMorningMusicAlarm alarm;

    Future<void> open(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.625;
      addTearDown(tester.view.reset);
      alarm = FakeMorningMusicAlarm();
      container = await pumpApp(tester, clock: () => now, morningMusic: alarm);
      await openTab(tester, 'Hub');
      await tester.tap(find.byTooltip('Spotify'));
      await tester.pumpAndSettle();
    }

    MorningMusic music() => container.read(preferencesProvider).morningMusic;
    String next(WidgetTester tester) =>
        tester.widget<Text>(find.byKey(const Key('spotifyNext'))).data!;

    testWidgets(
        'off at first; on, it says when it plays next; the phone told at '
        'once and on every change', (tester) async {
      await open(tester);
      expect(appBarTitle('Spotify'), findsOneWidget);
      expect(alarm.sent, [MorningMusic.initial], reason: 'set as it starts');
      expect(next(tester), 'Off');

      await tester.tap(find.byKey(const Key('spotifyOn')));
      await tester.pumpAndSettle();
      expect(music().on, isTrue);
      expect(next(tester), 'Next: Wed (tomorrow) at 07:00');
      expect(alarm.sent.last, music());

      // Days: Wednesday off, Tuesday's time gone: Thursday.
      await tester.tap(find.byKey(const Key('spotifyDay-3')));
      await tester.pumpAndSettle();
      expect(music().weekdays, {1, 2, 4, 5});
      expect(next(tester), 'Next: Thu at 07:00');
      // Saturday on.
      await tester.tap(find.byKey(const Key('spotifyDay-6')));
      await tester.pumpAndSettle();
      expect(music().weekdays, {1, 2, 4, 5, 6});
      expect(alarm.sent.last, music());

      // No day: says so.
      for (final d in [1, 2, 4, 5, 6]) {
        await tester.tap(find.byKey(Key('spotifyDay-$d')));
        await tester.pumpAndSettle();
      }
      expect(next(tester), 'Pick a day');
    });

    testWidgets('its time picked; its volume slid', (tester) async {
      await open(tester);
      await tester.tap(find.byKey(const Key('spotifyTime')));
      await tester.pumpAndSettle();
      // The dial's text entry: 13:30 typed.
      await tester.tap(find.byIcon(Icons.keyboard_outlined));
      await tester.pumpAndSettle();
      final fields = find.byType(TextField);
      await tester.enterText(fields.at(0), '13');
      await tester.enterText(fields.at(1), '30');
      await tester.tap(find.text('OK'));
      await tester.pumpAndSettle();
      expect(music().minutes, 13 * 60 + 30);
      expect(find.text('13:30'), findsOneWidget);

      final slider = find.byKey(const Key('spotifyVolume'));
      final box = tester.getRect(slider);
      await tester.tapAt(Offset(box.left + box.width * 0.75, box.center.dy));
      await tester.pumpAndSettle();
      expect(music().volume, inInclusiveRange(65, 85));
      expect(find.text('${music().volume}%'), findsOneWidget);
      expect(alarm.sent.last, music());
    });
  });
}
