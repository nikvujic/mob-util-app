import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/theme.dart';
import 'package:the_app/core/weather.dart';
import 'package:the_app/models/internet.dart';
import 'package:the_app/pages/internet/place_search_sheet.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/weather_provider.dart';
import 'package:the_app/widgets/pull_down_list.dart';
import 'package:the_app/widgets/text_input_sheet.dart';

/// Menu → Internet Access (Round 70): the app uses no internet unless a
/// service is turned on here, one section each: what it is, what it's
/// for, and its own settings once on. For now the weather (Open-Meteo),
/// for Pip's sky.
class InternetAccessPage extends ConsumerWidget {
  const InternetAccessPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final internet = ref.watch(preferencesProvider.select((p) => p.internet));
    final prefs = ref.read(preferencesProvider.notifier);
    void set(InternetSettings next) => prefs.setInternet(next);

    Future<void> addPlace() async {
      final place = await showPlaceSearchSheet(context);
      if (place == null) return;
      set(ref.read(preferencesProvider).internet.withPlace(place));
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Internet Access')),
      body: PullDownList.children(
        children: [
          Padding(
            key: const Key('internetIntro'),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.wifi_off, color: colors.textSecondary),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    'The app uses no internet unless you turn a service on '
                    'below. Everything else stays on this phone: no '
                    'accounts, no ads, no analytics.',
                    style: TextStyle(color: colors.textSecondary),
                  ),
                ),
              ],
            ),
          ),
          const Divider(),
          SwitchListTile(
            key: const Key('internetWeather'),
            secondary: const Icon(Icons.wb_cloudy_outlined),
            title: const Text('Weather'),
            subtitle: Text(
              'From Open-Meteo (open-meteo.com), free, with no account. '
              "Pip's sky shows the weather where you are: rain, snow, "
              'clouds, fog and storms. Only the place you search for, then '
              'its position, is sent; every hour or so while the app is '
              'open.',
              style: TextStyle(color: colors.textSecondary),
            ),
            value: internet.weather,
            onChanged: (on) => set(internet.copyWith(weather: on)),
          ),
          if (internet.weather) ...[
            for (final place in internet.places)
              _PlaceTile(
                place: place,
                picked: place.id == internet.place?.id,
                onPick: () => set(internet.copyWith(placeId: () => place.id)),
                onRemove: () => set(internet.withoutPlace(place.id)),
              ),
            ListTile(
              key: const Key('addPlace'),
              leading:
                  Icon(Icons.add_location_alt_outlined, color: colors.accent),
              title: Text(internet.places.isEmpty
                  ? 'Add your town or city'
                  : 'Add another place'),
              subtitle: internet.places.isEmpty
                  ? Text(
                      'Searched by name; you pick it from the matches.',
                      style: TextStyle(color: colors.textSecondary),
                    )
                  : null,
              onTap: addPlace,
            ),
            if (internet.place != null) const _WeatherNow(),
            const _RainRadar(),
          ],
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            child: Text(
              'More services may come here later, each off until turned on.',
              style: TextStyle(color: colors.textHint, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// A place added: picked for the weather with a tap; removed with ×.
class _PlaceTile extends StatelessWidget {
  final WeatherPlace place;
  final bool picked;
  final VoidCallback onPick;
  final VoidCallback onRemove;

  const _PlaceTile({
    required this.place,
    required this.picked,
    required this.onPick,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return ListTile(
      key: Key('weatherPlace-${place.id}'),
      leading: Icon(
        picked ? Icons.radio_button_checked : Icons.radio_button_unchecked,
        color: picked ? colors.accent : colors.textHint,
        semanticLabel: picked ? 'Picked' : null,
      ),
      title: Text(place.name),
      subtitle: place.where.isEmpty
          ? null
          : Text(place.where, style: TextStyle(color: colors.textSecondary)),
      selected: picked,
      onTap: onPick,
      trailing: IconButton(
        tooltip: 'Remove ${place.name}',
        icon: const Icon(Icons.close),
        onPressed: onRemove,
      ),
    );
  }
}

/// The weather now at the picked place, when it was fetched, and a
/// button to fetch it again; or why it couldn't be.
class _WeatherNow extends ConsumerWidget {
  const _WeatherNow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final internet = ref.watch(preferencesProvider.select((p) => p.internet));
    final fetch = ref.watch(weatherProvider);
    final now = ref.watch(clockProvider)();
    final report =
        internet.report?.placeId == internet.place?.id ? internet.report : null;
    final String text;
    if (fetch.busy) {
      text = 'Fetching the weather…';
    } else if (report != null) {
      final day = DateTime(now.year, now.month, now.day);
      final at = report.fetchedAt;
      final when = DateTime(at.year, at.month, at.day) == day
          ? formatMinutes(at.hour * 60 + at.minute)
          : formatDay(at, today: day);
      final kind = WeatherKind.fromCode(report.code)?.label ?? 'Weather';
      // Round 79: the wind too, when it came.
      final wind = report.wind == null ? '' : ', ${report.wind!.round()} km/h';
      // Round 106: where its rain or snow now came from, with a key.
      final source = internet.radarKey == null
          ? ''
          : report.radar
              ? ' · rain by radar'
              : ' · rain by Open-Meteo';
      text = 'Now: $kind, '
          '${report.temperature.round()}°C$wind · updated $when$source';
    } else {
      text = 'No weather yet';
    }
    return ListTile(
      key: const Key('weatherNow'),
      leading: const SizedBox(width: 24),
      title: Text(text, style: TextStyle(color: colors.textSecondary)),
      subtitle: fetch.failed != null
          ? Text(
              '${fetch.failed}. It tries again later.',
              key: const Key('weatherFailed'),
              style: TextStyle(color: colors.danger),
            )
          : fetch.radarFailed != null
              ? Text(
                  "${fetch.radarFailed}: Open-Meteo's weather meanwhile.",
                  key: const Key('radarFailed'),
                  style: TextStyle(color: colors.danger),
                )
              : null,
      trailing: IconButton(
        key: const Key('weatherRefresh'),
        tooltip: 'Fetch the weather now',
        icon: const Icon(Icons.refresh),
        onPressed: fetch.busy
            ? null
            : () => ref.read(weatherProvider.notifier).refresh(force: true),
      ),
    );
  }
}

/// Round 106: the rain radar, optional: his own free Tomorrow.io
/// key (where to get one copied, no link), pasted in, checked once; then
/// the rain or snow now comes from it. Removed with ×.
class _RainRadar extends ConsumerWidget {
  const _RainRadar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = context.colors;
    final key =
        ref.watch(preferencesProvider.select((p) => p.internet.radarKey));

    void toast(String message) => ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));

    void setKey(String? next) {
      final prefs = ref.read(preferencesProvider.notifier);
      prefs.setInternet(ref
          .read(preferencesProvider)
          .internet
          .copyWith(radarKey: () => next));
    }

    Future<void> paste() async {
      final typed = await showTextInputSheet(context,
          hint: 'Your Tomorrow.io key', initialValue: key ?? '');
      final next = typed ?? '';
      if (next.isEmpty || !context.mounted) return;
      setKey(next);
      toast('Checking the key…');
      final failed =
          await ref.read(weatherProvider.notifier).testRadarKey(next);
      if (context.mounted) toast(failed ?? 'The key works');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          key: const Key('radarNote'),
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 0),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.radar, color: colors.textSecondary),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  'Rain radar (optional). For more accurate rain and snow '
                  'right now, add your own free key from Tomorrow.io '
                  '(sign up at $radarSignUp). Without one, the '
                  'weather comes from Open-Meteo alone. The key stays on '
                  'this phone and is sent only to Tomorrow.io.',
                  style: TextStyle(color: colors.textSecondary),
                ),
              ),
              IconButton(
                key: const Key('copySignUp'),
                tooltip: 'Copy the sign-up address',
                icon: const Icon(Icons.copy),
                onPressed: () async {
                  await Clipboard.setData(
                      const ClipboardData(text: radarSignUp));
                  toast('Address copied');
                },
              ),
            ],
          ),
        ),
        ListTile(
          key: const Key('radarKey'),
          leading: Icon(Icons.key_outlined, color: colors.accent),
          title: Text(key == null ? 'Add your key' : 'Your key'),
          subtitle: Text(
            key == null
                ? 'Paste it in; it is checked once.'
                : '••••${key.length > 4 ? key.substring(key.length - 4) : key}',
            style: TextStyle(color: colors.textSecondary),
          ),
          onTap: paste,
          trailing: key == null
              ? null
              : IconButton(
                  key: const Key('removeRadarKey'),
                  tooltip: 'Remove the key',
                  icon: const Icon(Icons.close),
                  onPressed: () => setKey(null),
                ),
        ),
      ],
    );
  }
}
