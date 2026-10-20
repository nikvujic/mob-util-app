import 'dart:convert';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/data/morning_music_alarm.dart';
import 'package:the_app/models/morning_music.dart';
import 'package:the_app/models/internet.dart';
import 'package:the_app/data/weather_api.dart';
import 'package:the_app/core/pip_adventure.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/providers/weather_provider.dart';
import 'package:the_app/providers/pip_life_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:the_app/models/planner_task.dart';
import 'package:the_app/models/subscription.dart';
import 'package:the_app/core/app_info.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/data/backup_files.dart';
import 'package:the_app/models/preferences.dart';
import 'package:the_app/data/backup_folder.dart';
import 'package:the_app/data/power.dart';
import 'package:the_app/data/fingerprint_vault.dart';
import 'package:the_app/data/reminder_scheduler.dart';
import 'package:the_app/app/app.dart';
import 'package:the_app/providers/pip_provider.dart';

const testAppVersion = '1.2.3 (4)';

/// Opens the hamburger menu from the visible section.
Future<void> openMenu(WidgetTester tester) async {
  await tester.tap(find.byTooltip('Menu'));
  await tester.pumpAndSettle();
}

/// Scrolls the open menu's list until [label] is built and in view
/// (Round 70: on a short test screen the last items are below).
Future<void> scrollMenuTo(WidgetTester tester, String label) async {
  await tester.scrollUntilVisible(
    find.text(label),
    80,
    scrollable: find
        .descendant(of: find.byType(Drawer), matching: find.byType(Scrollable))
        .first,
  );
  await tester.pumpAndSettle();
}

/// Starts the whole app with in-memory storage and returns its provider
/// container, so tests can seed and inspect state.
Future<ProviderContainer> pumpApp(
  WidgetTester tester, {
  BackupFiles? backupFiles,
  DateTime Function()? clock,
  FingerprintVault? fingerprint,
  FakeReminderScheduler? reminders,
  bool introduction = false,
  bool pipMoves = false,
  bool pipHatched = true,
  PipLife? pip,
  PipLink? pipLink,
  bool realPipLink = false,
  BackupFolder? backupFolder,
  Preferences? preferences,
  PowerSource? power,
  FakeMorningMusicAlarm? morningMusic,
  FakeWeatherApi? weather,
  List<PlannerTask> plannerTasks = const [],
  SubscriptionBook subscriptions = SubscriptionBook.empty,
  List<Override> overrides = const [],
}) async {
  final container = ProviderContainer(
    overrides: [
      // Pip already out of his egg (Round 34), as on most phones by now;
      // his egg's own tests pass false.
      appStorageProvider.overrideWithValue(AppStorage.inMemory(
        initialPip: pip ??
            (pipHatched ? PipLife(born: DateTime(2026, 10, 1)) : PipLife.egg),
        initialPreferences: preferences ?? const Preferences(),
        initialPlannerTasks: plannerTasks,
        initialSubscriptions: subscriptions,
      )),
      // Automatic backup's folder (Round 39): a fake, never Android's.
      backupFolderProvider
          .overrideWithValue(backupFolder ?? FakeBackupFolder()),
      appVersionProvider.overrideWithValue(testAppVersion),
      // The phone's power (Round 44): a fake, unplugged unless told.
      powerSourceProvider.overrideWithValue(power ?? FakePower()),
      morningMusicAlarmProvider
          .overrideWithValue(morningMusic ?? FakeMorningMusicAlarm()),
      backupFilesProvider.overrideWithValue(backupFiles ?? FakeBackupFiles()),
      fingerprintVaultProvider.overrideWithValue(
        fingerprint ?? FakeFingerprintVault(available: false),
      ),
      reminderSchedulerProvider.overrideWithValue(
        reminders ?? FakeReminderScheduler(),
      ),
      if (clock != null) clockProvider.overrideWithValue(clock),
      // The weather (Round 70): never the real service.
      weatherApiProvider.overrideWithValue(weather ?? FakeWeatherApi()),
      // Pip stands still (an endless animation never settles); his own
      // tests let him move.
      pipAnimatesProvider.overrideWithValue(pipMoves),
      // His life (Round 37) as a test sets it: awake and full unless it
      // says; [realPipLink] for the real one, by the test's clock.
      if (!realPipLink)
        pipLinkProvider.overrideWithValue(pipLink ?? FakePipLink()),
      // The Introduction note (N16) only where a test asks for it.
      if (introduction)
        startedVersionProvider.overrideWithValue(testAppVersion),
      ...overrides,
    ],
  );
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const MyApp()),
  );
  return container;
}

/// Switches to a main section via the bottom navigation bar.
Future<void> openTab(WidgetTester tester, String label) async {
  await tester.tap(
    find.descendant(
      of: find.byType(BottomNavigationBar),
      matching: find.text(label),
    ),
  );
  await tester.pumpAndSettle();
}

/// Finds [title] inside the app bar of the visible page.
Finder appBarTitle(String title) => find.descendant(
      of: find.byType(AppBar),
      matching: find.text(title),
    );

/// Records whether the app asked Android to close it
/// (`SystemNavigator.pop`), which is what system back does on the root page.
class ExitRecorder {
  int exits = 0;

  ExitRecorder(WidgetTester tester) {
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'SystemNavigator.pop') exits++;
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
  }
}

/// Simulates the Android system back button.
Future<void> pressBack(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}

/// Leaves a page saved as it's typed (Round 91: subscriptions, dates,
/// meals) with back, answering Save if it asks.
Future<void> leaveSaved(WidgetTester tester) async {
  await pressBack(tester);
  final save = find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(FilledButton, 'Save'));
  if (save.evaluate().isNotEmpty) {
    await tester.tap(save);
    await tester.pumpAndSettle();
  }
}

/// Leaves the note editor with back. If [save] is given, the "Save
/// changes?" dialog is expected and answered with Save (true) or Discard
/// (false).
Future<void> leaveNote(WidgetTester tester, {bool? save}) async {
  await tester.pump(); // let pending text changes settle
  await tester.pageBack();
  await tester.pumpAndSettle();
  if (save != null) {
    await tester.tap(find.text(save ? 'Save' : 'Discard'));
    await tester.pumpAndSettle();
  }
}

/// Stands in for the system file dialogs. Saving: by default the user
/// "saves"; set [cancel] to simulate closing the dialog, [error] to make
/// saving fail, or [pending] to keep the dialog open until the test
/// completes it. Picking: returns [toPick] (null = the user cancelled).
class FakeBackupFiles implements BackupFiles {
  bool cancel = false;
  Object? error;
  Completer<bool>? pending;
  Uint8List? toPick;

  @override
  Future<Uint8List?> pick() async => toPick;

  final saved = <({String fileName, Uint8List bytes})>[];

  @override
  Future<bool> save({required String fileName, required Uint8List bytes}) {
    if (error != null) return Future.error(error!);
    if (pending != null) return pending!.future;
    if (cancel) return Future.value(false);
    saved.add((fileName: fileName, bytes: bytes));
    return Future.value(true);
  }
}

/// Lets real asynchronous work started by the UI finish (e.g. key
/// derivation in a background isolate, which the test's fake clock can't
/// wait for): waits in real time until no progress spinner is left.
Future<void> settleBusy(WidgetTester tester) async {
  for (var i = 0; i < 400; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    // Advance the clock too, so e.g. a closing page's transition finishes.
    await tester.pump(const Duration(milliseconds: 25));
    if (find.byType(CircularProgressIndicator).evaluate().isEmpty) break;
  }
  await tester.pumpAndSettle();
}

/// A fingerprint keystore (L6) for tests: [nextFinger] decides how the
/// next fingerprint request goes.
class FakeFingerprintVault implements FingerprintVault {
  bool available;

  /// What's stored, or null.
  String? stored;

  /// How the next fingerprint request ends: true matches, false cancels,
  /// null means the stored key is void (e.g. a new fingerprint enrolled).
  bool? nextFinger = true;

  /// Fingerprint requests so far.
  int asked = 0;

  FakeFingerprintVault({this.available = true});

  @override
  Future<bool> isAvailable() async => available;

  @override
  Future<bool> store(String secret) async {
    asked++;
    if (nextFinger != true) return false;
    stored = secret;
    return true;
  }

  @override
  Future<VaultRead> read() async {
    asked++;
    final secret = stored;
    return switch (nextFinger) {
      true when secret != null => VaultOpened(secret),
      false => const VaultCancelled(),
      _ => const VaultBroken(),
    };
  }

  @override
  Future<void> clear() async => stored = null;
}

/// Records the reminders the app schedules (P10), instead of showing them.
class FakeReminderScheduler implements ReminderScheduler {
  /// What's scheduled now.
  List<Reminder> scheduled = const [];

  /// [scheduled] but the planner's notifications that stay while a block
  /// is on (Round 72).
  List<Reminder> get scheduledReminders => [
        for (final r in scheduled)
          if (r.kind != ReminderKind.plannerNow) r
      ];

  /// Whether notifications are allowed; [asked] counts the requests.
  bool allowed = true;
  int asked = 0;

  @override
  Future<bool> requestPermission() async {
    asked++;
    return allowed;
  }

  @override
  Future<bool> areAllowed() async => allowed;

  @override
  Future<void> replaceAll(List<Reminder> reminders) async {
    scheduled = List.of(reminders);
  }

  /// The kinds whose shown notifications were cleared (Round 61).
  final cleared = <ReminderKind>[];

  @override
  Future<void> clearShown(ReminderKind kind) async => cleared.add(kind);

  /// Taps on notifications: add a [Reminder.target] to tap one.
  final taps = StreamController<String>.broadcast();

  @override
  Stream<String> get opened => taps.stream;

  /// The notification that started the app, if any.
  String? launch;

  @override
  Future<String?> takeLaunch() async {
    final target = launch;
    launch = null;
    return target;
  }
}

/// Taps [finder] the way a screen reader does: its semantics action, with
/// no point on the screen (e.g. free time then adds by its own rules, not
/// near a finger).
Future<void> tapAsScreenReader(WidgetTester tester, Finder finder) async {
  final handle = tester.ensureSemantics();
  final node = tester.getSemantics(finder);
  node.owner!.performAction(node.id, SemanticsAction.tap);
  await tester.pumpAndSettle();
  handle.dispose();
}

/// Brings [finder] into view on the page on top: scrolling its list down
/// until it's built, then to it (wherever it is).
Future<void> reveal(WidgetTester tester, Finder finder) async {
  if (finder.evaluate().isEmpty) {
    await tester.scrollUntilVisible(finder, 100,
        scrollable: find.byType(Scrollable).last);
  }
  await tester.ensureVisible(finder);
  await tester.pumpAndSettle();
}

/// Pip's life for tests (Round 37): shows [show] with [segments], and
/// gives batteries while [batteries] last; records what was shown.
class FakePipLink implements PipLink {
  PipShow show;
  int segments;
  int batteries;
  final List<PipShow> seen = [];

  FakePipLink({
    this.show = PipShow.awake,
    this.segments = 3,
    this.batteries = 0,
  });

  @override
  (PipShow, int) look() => (show, segments);

  @override
  void shown(PipShow show) => seen.add(show);

  @override
  bool giveBattery() {
    if (batteries == 0) return false;
    batteries--;
    return true;
  }

  /// Round 77: three taps wake him while [wakeable] (then awake, drowsy
  /// if [drowsyWoken]); how many times he was.
  bool wakeable = false;
  bool drowsyWoken = true;
  int wakes = 0;
  @override
  bool drowsy = false;

  @override
  bool wake() {
    if (!wakeable) return false;
    wakeable = false;
    wakes++;
    show = PipShow.awake;
    drowsy = drowsyWoken;
    return true;
  }

  /// The phone plugged in (Round 44).
  @override
  bool plugged = false;

  /// The time (Round 52); the real one unless a test sets it.
  DateTime? at;
  @override
  DateTime get now => at ?? DateTime.now();

  /// When notifications came (Round 52).
  final List<DateTime> notifications = [];
  @override
  bool notifiedBetween(DateTime from, DateTime to) =>
      notifications.any((n) => n.isAfter(from) && !n.isAfter(to));

  /// A medicine due (Round 53).
  @override
  bool medicineDue = false;

  /// When a recipe was read a while (Round 53).
  @override
  DateTime? recipeReadAt;

  /// A birthday today (Round 57).
  @override
  bool partyHat = false;

  /// Today's hat otherwise (Round 61).
  @override
  PipHat? hatToday;

  /// Segments from his station (Round 58): one more each (not full); off,
  /// he's on again.
  int charges = 0;
  @override
  bool chargeTick() {
    if (segments >= 3) return false;
    charges++;
    segments++;
    if (show == PipShow.off || show == PipShow.powerOff) show = PipShow.awake;
    return true;
  }

  /// Out on his adventure (Round 63): what [outing] says.
  PipOut? out;

  @override
  PipOut? outing() => out;

  /// His ski trip (Round 67): what [trip] says.
  PipTripNow ride = noTrip;

  @override
  PipTripNow trip() => ride;

  @override
  int level = 1;

  /// Round 73: whether he's watched fighting, what was struck down (true:
  /// a boss), and the XP each brings.
  bool? fightingNow;
  final defeats = <bool>[];
  int xpEach = 1;

  @override
  void fighting(bool on) => fightingNow = on;

  @override
  int defeated({bool boss = false}) {
    defeats.add(boss);
    return boss ? 50 : xpEach;
  }

  @override
  bool bossDue = false;

  /// Round 74: how long he's been running out (seconds).
  double? running;

  @override
  double? outRun() => running;
}

/// Whether the phone is plugged in, in tests (Round 44): [isPlugged]
/// now; [plug] tells the app it changed.
/// Spotify's morning alarm (Round 93): what the phone was last told.
class FakeMorningMusicAlarm implements MorningMusicAlarm {
  final sent = <MorningMusic>[];

  @override
  Future<void> set(MorningMusic music) async => sent.add(music);
}

class FakePower implements PowerSource {
  bool isPlugged;
  final _changes = StreamController<bool>.broadcast();

  FakePower({this.isPlugged = false});

  @override
  Future<bool> plugged() async => isPlugged;

  @override
  Stream<bool> get changes => _changes.stream;

  void plug(bool plugged) {
    isPlugged = plugged;
    _changes.add(plugged);
  }
}

/// A folder for automatic backups in tests (Round 39): [picks] what
/// [pick] returns, [works] whether writing does; records what's written.
class FakeBackupFolder implements BackupFolder {
  PickedFolder? picks;
  bool works;
  final List<
          ({String folder, String name, String text, String prefix, int keep})>
      written = [];

  FakeBackupFolder({this.picks, this.works = true});

  @override
  Future<PickedFolder?> pick() async => picks;

  @override
  Future<bool> write({
    required String folder,
    required String name,
    required Uint8List bytes,
    required String prefix,
    required int keep,
  }) async {
    if (!works) return false;
    written.add((
      folder: folder,
      name: name,
      text: utf8.decode(bytes),
      prefix: prefix,
      keep: keep,
    ));
    return true;
  }
}

/// The weather service (Round 70) as a test sets it: [places] for any
/// search, [report] for any place; [failing] throws instead. Counts its
/// calls.
class FakeWeatherApi implements WeatherApi {
  List<WeatherPlace> places;

  /// A WMO code (61: rain).
  int code;
  double temperature;
  String? failing;
  int searches = 0;
  int fetches = 0;

  FakeWeatherApi({
    this.places = const [],
    this.code = 61,
    this.temperature = 7.4,
    this.failing,
  });

  @override
  Future<List<WeatherPlace>> search(String name) async {
    searches++;
    if (failing case final message?) throw WeatherFailure(message);
    return places;
  }

  @override
  Future<WeatherReport> now(WeatherPlace place, DateTime at) async {
    fetches++;
    if (failing case final message?) throw WeatherFailure(message);
    return WeatherReport(
      placeId: place.id,
      code: code,
      temperature: temperature,
      fetchedAt: at,
    );
  }
}
