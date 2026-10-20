import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/models/hub_tool.dart';
import 'package:the_app/models/morning_music.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/widgets/pull_down_list.dart';

/// Spotify in the morning (Round 93, Nikola: a page with no list, just
/// its settings): on or off, the time, the days, and the volume. At that
/// time the phone sets the music volume and presses play, so Spotify
/// carries on with what it last played. Saved as it's changed.
class SpotifyPage extends ConsumerWidget {
  const SpotifyPage({super.key});

  /// A week's days, Monday first, as `DateTime.weekday` counts them.
  static const _days = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final music = ref.watch(preferencesProvider.select((p) => p.morningMusic));
    final prefs = ref.read(preferencesProvider.notifier);
    void change(MorningMusic m) => prefs.setMorningMusic(m);
    final colors = context.colors;
    final now = ref.watch(clockProvider)();
    final next = music.nextAfter(now);

    Widget heading(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            text,
            style: TextStyle(
              color: colors.accent,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              letterSpacing: 1,
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: Text(HubTool.spotify.label)),
      body: PullDownList.children(
        children: [
          SwitchListTile(
            key: const Key('spotifyOn'),
            title: const Text('Play in the morning'),
            subtitle: Text(
              key: const Key('spotifyNext'),
              switch ((music.on, next)) {
                (false, _) => 'Off',
                (true, null) => 'Pick a day',
                (true, final at?) => 'Next: '
                    '${formatDay(at, today: now).split(', ').first}'
                    '${_soon(at, now)} at ${formatMinutes(music.minutes)}',
              },
            ),
            value: music.on,
            onChanged: (on) => change(music.copyWith(on: on)),
          ),
          ListTile(
            key: const Key('spotifyTime'),
            leading: const Icon(Icons.alarm),
            title: const Text('Time'),
            trailing: Text(
              formatMinutes(music.minutes),
              style: TextStyle(color: colors.textPrimary, fontSize: 16),
            ),
            onTap: () async {
              final picked = await showTimePicker(
                context: context,
                initialTime: TimeOfDay(
                    hour: music.minutes ~/ 60, minute: music.minutes % 60),
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(alwaysUse24HourFormat: true),
                  child: child!,
                ),
              );
              if (picked == null) return;
              change(ref
                  .read(preferencesProvider)
                  .morningMusic
                  .copyWith(minutes: picked.hour * 60 + picked.minute));
            },
          ),
          heading('DAYS'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (var day = 1; day <= 7; day++)
                  FilterChip(
                    key: Key('spotifyDay-$day'),
                    label: Text(_days[day - 1]),
                    selected: music.weekdays.contains(day),
                    onSelected: (picked) => change(music.copyWith(
                      weekdays: picked
                          ? {...music.weekdays, day}
                          : ({...music.weekdays}..remove(day)),
                    )),
                  ),
              ],
            ),
          ),
          heading('VOLUME'),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: [
                Icon(Icons.volume_down, color: colors.textSecondary),
                Expanded(
                  child: Slider(
                    key: const Key('spotifyVolume'),
                    value: music.volume.toDouble(),
                    max: 100,
                    divisions: 20,
                    label: '${music.volume}%',
                    onChanged: (v) => change(music.copyWith(volume: v.round())),
                  ),
                ),
                SizedBox(
                  width: 48,
                  child: Text(
                    '${music.volume}%',
                    key: const Key('spotifyVolumeText'),
                    textAlign: TextAlign.end,
                    style: TextStyle(color: colors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            child: Text(
              'At that time the phone sets its music volume and presses '
              'play: Spotify carries on with what it last played. If '
              'Spotify was closed completely, it may not start.',
              style: TextStyle(color: colors.textMuted, height: 1.4),
            ),
          ),
        ],
      ),
    );
  }

  /// " (today)", " (tomorrow)", or nothing further off.
  static String _soon(DateTime at, DateTime now) =>
      switch (daysBetween(now, at)) {
        0 => ' (today)',
        1 => ' (tomorrow)',
        _ => '',
      };
}
