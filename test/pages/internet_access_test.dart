import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/internet.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/weather_provider.dart';

import '../helpers.dart';

/// Menu → Internet Access (Round 70): nothing used unless turned on; the
/// weather's places, picked from a search; the weather fetched for one.
void main() {
  const noviSad = WeatherPlace(
    id: '3194360',
    name: 'Novi Sad',
    region: 'Vojvodina',
    country: 'Serbia',
    latitude: 45.25,
    longitude: 19.84,
  );
  const beograd = WeatherPlace(
    id: '792680',
    name: 'Belgrade',
    region: 'Central Serbia',
    country: 'Serbia',
    latitude: 44.8,
    longitude: 20.47,
  );
  final now = DateTime(2026, 10, 19, 10, 20);
  late ProviderContainer container;
  late FakeWeatherApi api;
  late FakeRadarApi radar;

  InternetSettings internet() => container.read(preferencesProvider).internet;

  Future<void> openPage(WidgetTester tester,
      {InternetSettings settings = const InternetSettings(),
      int weatherCode = 61}) async {
    api = FakeWeatherApi(places: const [noviSad, beograd], code: weatherCode);
    radar = FakeRadarApi();
    container = await pumpApp(
      tester,
      clock: () => now,
      weather: api,
      radar: radar,
      preferences: Preferences(internet: settings),
    );
    await openMenu(tester);
    await tester.tap(find.text('Internet Access'));
    await tester.pumpAndSettle();
  }

  /// Turned off at the end, so its timer stops.
  Future<void> turnOff(WidgetTester tester) async {
    container
        .read(preferencesProvider.notifier)
        .setInternet(internet().copyWith(weather: false));
    await tester.pumpAndSettle();
  }

  testWidgets('in the menu, second to last; nothing on, nothing fetched',
      (tester) async {
    await openPage(tester);
    expect(find.text('Internet Access'), findsWidgets);
    expect(find.byKey(const Key('internetIntro')), findsOneWidget);
    expect(
        tester
            .widget<SwitchListTile>(find.byKey(const Key('internetWeather')))
            .value,
        isFalse);
    expect(find.byKey(const Key('addPlace')), findsNothing);
    expect((api.searches, api.fetches), (0, 0));
  });

  testWidgets(
      'turned on: a place searched, picked from the matches, and its '
      'weather fetched', (tester) async {
    await openPage(tester);
    await tester.tap(find.byKey(const Key('internetWeather')));
    await tester.pumpAndSettle();
    expect(find.text('Add your town or city'), findsOneWidget);
    expect(api.fetches, 0, reason: 'no place yet');

    await tester.tap(find.byKey(const Key('addPlace')));
    await tester.pumpAndSettle();
    await tester.enterText(
        find.byKey(const Key('placeSearchField')), 'Novi Sad');
    await tester.testTextInput.receiveAction(TextInputAction.search);
    await tester.pumpAndSettle();
    expect(api.searches, 1);
    expect(find.text('Vojvodina, Serbia'), findsOneWidget);
    await tester.tap(find.byKey(const Key('place-3194360')));
    await tester.pumpAndSettle();

    expect(internet().places, [noviSad]);
    expect(internet().place, noviSad);
    expect(api.fetches, 1);
    expect(internet().report!.code, 61);
    expect(find.text('Now: Rain, 7°C · updated 10:20'), findsOneWidget);
    expect(find.text('Add another place'), findsOneWidget);
    await turnOff(tester);
  });

  testWidgets('several places: a tap picks one (fetched for it); × removes one',
      (tester) async {
    await openPage(tester,
        settings: const InternetSettings(
            weather: true, places: [noviSad, beograd], placeId: '3194360'));
    await tester.pumpAndSettle();
    expect(api.fetches, 1, reason: 'turned on with a place: fetched');
    await tester.tap(find.text('Belgrade'));
    await tester.pumpAndSettle();
    expect(internet().place, beograd);
    expect(internet().report!.placeId, beograd.id);
    expect(api.fetches, 2);

    await tester.tap(find.byTooltip('Remove Belgrade'));
    await tester.pumpAndSettle();
    expect(internet().places, [noviSad]);
    expect(internet().place, noviSad);
    expect(internet().report?.placeId, isNot(beograd.id));
    await turnOff(tester);
  });

  testWidgets('a fresh report isn\'t fetched again; the button does',
      (tester) async {
    await openPage(tester,
        settings: InternetSettings(
          weather: true,
          places: const [noviSad],
          report: WeatherReport(
            placeId: noviSad.id,
            code: 73,
            temperature: -2,
            wind: 18.4,
            fetchedAt: now.subtract(const Duration(minutes: 20)),
          ),
        ));
    await tester.pumpAndSettle();
    expect(api.fetches, 0);
    // Round 79: with its wind.
    expect(
        find.text('Now: Snow, -2°C, 18 km/h · updated 10:00'), findsOneWidget);
    await tester.tap(find.byKey(const Key('weatherRefresh')));
    await tester.pumpAndSettle();
    expect(api.fetches, 1);
    expect(internet().report!.code, 61);
    await turnOff(tester);
  });

  testWidgets('no place found, or no connection: it says so, nothing saved',
      (tester) async {
    await openPage(tester, settings: const InternetSettings(weather: true));
    api.places = const [];
    await tester.tap(find.byKey(const Key('addPlace')));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('placeSearchField')), 'Nvi');
    await tester.tap(find.byKey(const Key('placeSearch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placeNotFound')), findsOneWidget);

    api.failing = 'No connection to the weather service';
    await tester.tap(find.byKey(const Key('placeSearch')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('placeNotFound')), findsNothing);
    expect(
        find.text('No connection to the weather service. Check the '
            'connection and try again.'),
        findsOneWidget);
    await pressBack(tester);
    expect(internet().places, isEmpty);
    await turnOff(tester);
  });

  testWidgets('a failed fetch says so, and the last report stays',
      (tester) async {
    final old = WeatherReport(
      placeId: noviSad.id,
      code: 0,
      temperature: 12,
      fetchedAt: now.subtract(const Duration(hours: 2)),
    );
    api = FakeWeatherApi(failing: 'No connection to the weather service');
    container = await pumpApp(
      tester,
      clock: () => now,
      weather: api,
      preferences: Preferences(
          internet: InternetSettings(
              weather: true, places: const [noviSad], report: old)),
    );
    await openMenu(tester);
    await tester.tap(find.text('Internet Access'));
    await tester.pumpAndSettle();
    expect(api.fetches, 1, reason: 'two hours old: fetched again');
    expect(find.byKey(const Key('weatherFailed')), findsOneWidget);
    expect(internet().report!.code, 0);
    await turnOff(tester);
  });

  group('the rain radar, with his own key (Round 106)', () {
    final on = InternetSettings(weather: true, places: const [beograd]);
    String? clipboard;
    setUp(() {
      clipboard = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
        if (call.method == 'Clipboard.setData') {
          clipboard = (call.arguments as Map)['text'] as String;
        }
        return null;
      });
    });
    tearDown(() => TestDefaultBinaryMessengerBinding
        .instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null));

    Future<void> pasteKey(WidgetTester tester, String key) async {
      await tester.ensureVisible(find.byKey(const Key('radarKey')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('radarKey')));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).last, key);
      await tester.tap(find.text('Save'));
      await tester.pumpAndSettle();
    }

    testWidgets(
        'no key: the radar never asked; the note, its address copied '
        '(no link)', (tester) async {
      await openPage(tester, settings: on, weatherCode: 3);
      await tester.pumpAndSettle();
      expect(api.fetches, 1);
      expect(radar.keys, isEmpty);
      expect(find.text('Now: Cloudy, 7°C · updated 10:20'), findsOneWidget,
          reason: 'no source said without a key');
      expect(find.textContaining('Rain radar (optional)'), findsOneWidget);
      expect(find.text('Add your key'), findsOneWidget);
      await tester.ensureVisible(find.byKey(const Key('copySignUp')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('copySignUp')));
      await tester.pumpAndSettle();
      expect(clipboard, radarSignUp);
      expect(find.text('Address copied'), findsOneWidget);
      await turnOff(tester);
    });

    testWidgets(
        'a key pasted: checked once, then its rain wins over '
        "Open-Meteo's clouds; shown by its end only; × removes it",
        (tester) async {
      await openPage(tester, settings: on, weatherCode: 3);
      await tester.pumpAndSettle();
      radar.code = 63;
      await pasteKey(tester, '  abcdef1234wxyz ');
      expect(internet().radarKey, 'abcdef1234wxyz');
      expect(radar.keys, everyElement('abcdef1234wxyz'));
      expect(radar.keys, hasLength(2), reason: 'the check, the fetch');
      expect(find.text('The key works'), findsOneWidget);
      expect(find.text('••••wxyz'), findsOneWidget);
      expect(find.textContaining('abcdef'), findsNothing);
      expect(internet().report!.code, 63);
      expect(internet().report!.radar, isTrue);
      expect(find.text('Now: Rain, 7°C · updated 10:20 · rain by radar'),
          findsOneWidget);

      await tester.ensureVisible(find.byKey(const Key('removeRadarKey')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('removeRadarKey')));
      await tester.pumpAndSettle();
      expect(internet().radarKey, isNull);
      expect(internet().report!.code, 3, reason: "Open-Meteo's again");
      expect(find.text('Add your key'), findsOneWidget);
      await turnOff(tester);
    });

    testWidgets("dry by radar: Open-Meteo's sky stands", (tester) async {
      await openPage(tester,
          settings: on.copyWith(radarKey: () => 'k1'), weatherCode: 2);
      await tester.pumpAndSettle();
      expect(radar.keys, ['k1']);
      expect(internet().report!.code, 2);
      expect(internet().report!.radar, isTrue);
      await turnOff(tester);
    });

    testWidgets("the radar failing: Open-Meteo's weather, and it says why",
        (tester) async {
      await openPage(tester, settings: on, weatherCode: 3);
      await tester.pumpAndSettle();
      radar.failing = "The rain radar didn't accept the key";
      await pasteKey(tester, 'bad');
      expect(find.text("The rain radar didn't accept the key"), findsOneWidget,
          reason: 'the check');
      expect(internet().radarKey, 'bad', reason: 'kept: it may come back');
      expect(internet().report!.code, 3);
      expect(internet().report!.radar, isFalse);
      expect(
          find.text("The rain radar didn't accept the key: Open-Meteo's "
              'weather meanwhile.'),
          findsOneWidget);
      expect(
          find.text('Now: Cloudy, 7°C · updated 10:20 · rain by '
              'Open-Meteo'),
          findsOneWidget);
      await turnOff(tester);
    });

    WeatherReport fifteenOld() => WeatherReport(
          placeId: beograd.id,
          code: 3,
          temperature: 5,
          fetchedAt: now.subtract(const Duration(minutes: 15)),
        );

    testWidgets('without a key, a report 15 minutes old is fresh enough',
        (tester) async {
      await openPage(tester, settings: on.copyWith(report: fifteenOld));
      await tester.pumpAndSettle();
      expect(api.fetches, 0);
      await turnOff(tester);
    });

    testWidgets('with a key, a report 15 minutes old is fetched again',
        (tester) async {
      await openPage(tester,
          settings: on.copyWith(report: fifteenOld, radarKey: () => 'k'));
      await tester.pumpAndSettle();
      expect(api.fetches, 1);
      expect(radar.keys, ['k']);
      await turnOff(tester);
    });
  });
}
