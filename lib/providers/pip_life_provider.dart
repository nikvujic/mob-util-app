import 'dart:async';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:the_app/core/clock.dart';
import 'package:the_app/core/format.dart';
import 'package:the_app/core/pip_adventure.dart';
import 'package:the_app/core/pip_energy.dart';
import 'package:the_app/core/pip_hats.dart';
import 'package:the_app/core/pip_quest.dart';
import 'package:the_app/core/pip_brain.dart';
import 'package:the_app/data/app_storage.dart';
import 'package:the_app/data/power.dart';
import 'package:the_app/models/date_entry.dart';
import 'package:the_app/models/pip_life.dart';
import 'package:the_app/providers/dates_provider.dart';
import 'package:the_app/providers/medicine_alerts_provider.dart';
import 'package:the_app/providers/medicine_provider.dart';
import 'package:the_app/providers/notification_log_provider.dart';
import 'package:the_app/providers/pip_trip.dart';
import 'package:the_app/providers/preferences_provider.dart';
import 'package:the_app/providers/recipe_read_provider.dart';

/// Pip, the pet (Round 34): an egg until hatched, then his birthday and
/// name; his energy and batteries (Round 37). Saved to `pip.json`.
class PipLifeNotifier extends StateNotifier<PipLife> {
  final DateTime Function() _clock;

  /// The dates (Round 67: his ski trips' buses, his days out on them).
  final DateBook Function() _dates;

  PipLifeNotifier(
    AppStorage storage, {
    DateTime Function()? clock,
    DateBook Function()? dates,
  })  : _clock = clock ?? DateTime.now,
        _dates = dates ?? (() => DateBook.empty),
        super(storage.initialPip) {
    state = _started(state);
    addListener(storage.savePip, fireImmediately: false);
  }

  /// A Pip from before Round 37 (or such a backup): full from now on,
  /// his first battery on its way.
  PipLife _started(PipLife pip) {
    if (!pip.hatched || pip.energyAt != null) return pip;
    final now = _clock();
    return pip.copyWith(
      energyAt: () => now,
      nextBatteryAt: () => pip.nextBatteryAt ?? PipEnergy.nextBattery(now),
    );
  }

  /// He's out, at [now]: that's his birthday. Once only. Round 61: two
  /// segments and a battery in hand (so there's one to give him), the
  /// next on its way.
  static const hatchEnergy = 2.0;
  static const hatchBatteries = 1;
  void hatch(DateTime now) {
    if (state.hatched) return;
    state = state.copyWith(
      born: now,
      energy: hatchEnergy,
      energyAt: () => now,
      batteries: hatchBatteries,
      nextBatteryAt: () => PipEnergy.nextBattery(now),
    );
  }

  /// A new name: trimmed, at most [maxName] letters (Round 35: 6, so
  /// it never overflows); blank keeps his.
  static const maxName = 6;
  void rename(String name) {
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;
    state = state.copyWith(
      name: trimmed.length > maxName ? trimmed.substring(0, maxName) : trimmed,
    );
  }

  /// The phone is plugged in (Round 44): he can't lose power meanwhile.
  bool _charging = false;
  bool get charging => _charging;

  /// Whether the phone is plugged in, as known at [now]: his energy is
  /// taken as it is then, and from then on kept (charging) or used
  /// (not).
  void setCharging(bool charging, DateTime now) {
    if (charging == _charging) return;
    _settle(now);
    if (state.hatched) {
      state = state.copyWith(energy: levelAt(now), energyAt: () => now);
    }
    _charging = charging;
  }

  /// Plugged in when last seen (after a restart): charging since then,
  /// his energy as it was.
  void resumeCharging(bool charging) => _charging = charging;

  /// His battery icon's segments at [now]: what he has (Round 58: also
  /// plugged in; it used to keep what he was plugged in with).
  int segmentsAt(DateTime now) => PipEnergy.segments(levelAt(now));

  /// His energy at [now]. Round 63: out on an adventure he can't power
  /// down; he does once it's over, if he's run out by then.
  double levelAt(DateTime now) {
    final since = state.energyAt ?? now;
    // Round 67: on his ski trip's bus, he uses none.
    final level = PipEnergy.levelPausing(
      state.energy,
      since,
      now,
      [
        for (final r in PipTrip.ridesNear(_dates(), now))
          if (r.to.isAfter(since) && r.from.isBefore(now)) (r.from, r.to),
      ],
      rule: _charging ? PipEnergy.chargingLevelAt : PipEnergy.levelAt,
    );
    return outAt(now) ? math.max(level, adventureFloor) : level;
  }

  /// What he keeps, out, however long it's been (a few minutes' worth).
  static const adventureFloor = 0.01;

  /// Out on his adventure at [now] (Round 63).
  bool outAt(DateTime now) {
    final from = state.outFrom;
    return from != null &&
        !now.isBefore(from) &&
        now.isBefore(PipAdventure.endOf(from));
  }

  /// On his break at [now] (Round 64).
  bool onBreakAt(DateTime now) {
    final at = state.breakAt;
    return outAt(now) &&
        at != null &&
        !now.isBefore(at) &&
        now.isBefore(at.add(PipAdventure.breakLength));
  }

  /// His XP at [now]: what's banked and this day out so far (Round 73:
  /// an XP every six seconds of it).
  int xpAt(DateTime now) {
    final banked = state.minutesOut * PipAdventure.xpPerMinute;
    final from = state.outFrom;
    if (from == null || !now.isAfter(from)) return banked;
    final end = PipAdventure.endOf(from);
    final seconds = (now.isBefore(end) ? now : end).difference(from).inSeconds;
    return banked + seconds * PipAdventure.xpPerMinute ~/ 60;
  }

  /// His XP as shown at [now] (Round 73): while he's watched fighting,
  /// what it was at the last bug he struck ([held], kept up while his
  /// room is shown); else (or once his room's gone a moment) as it is.
  int shownXpAt(DateTime now, PipHeldXp? held) {
    final xp = xpAt(now);
    if (held == null || now.difference(held.at).abs() > heldFor) return xp;
    return math.min(held.xp, xp);
  }

  /// How long a hold lasts unless his room keeps it up (it does every
  /// second while shown).
  static const heldFor = Duration(seconds: 3);

  /// How long he's been running at [now] on his day out (seconds, his
  /// break not counted), or null: not out (Round 74).
  double? runningAt(DateTime now) {
    final from = state.outFrom;
    if (from == null || !outAt(now)) return null;
    var seconds = now.difference(from).inMilliseconds / 1000;
    final at = state.breakAt;
    if (at != null && now.isAfter(at)) {
      final off = now.difference(at);
      seconds -=
          (off < PipAdventure.breakLength ? off : PipAdventure.breakLength)
                  .inMilliseconds /
              1000;
    }
    return seconds;
  }

  /// The day out a boss was beaten on (Round 73: one a day out). In
  /// memory: the app's first look is a fresh one.
  String? _bossDay;

  /// Whether a boss may still come at [now]: out, none beaten today.
  bool bossDueAt(DateTime now) => outAt(now) && _bossDay != state.outDay;

  /// A boss beaten at [now] (Round 73): [PipAdventure.bossMinutes] more
  /// banked, once a day out. The XP it brought (none if not due).
  int bossBeaten(DateTime now) {
    if (!bossDueAt(now)) return 0;
    _bossDay = state.outDay;
    state =
        state.copyWith(minutesOut: state.minutesOut + PipAdventure.bossMinutes);
    return PipAdventure.bossMinutes * PipAdventure.xpPerMinute;
  }

  /// Registers him as an adventurer at [now] (Round 63): only between
  /// 13:00 and 17:00, once. His energy is filled and he goes out at once.
  /// True if he was.
  bool register(DateTime now) {
    if (!state.hatched ||
        state.adventurer ||
        !PipAdventure.canRegisterAt(now)) {
      return false;
    }
    state = state.copyWith(
      registeredAt: () => now,
      energy: PipLife.fullEnergy,
      energyAt: () => now,
      offSeen: false,
      outDay: () => dayKey(now),
      // On the minute (Round 73: so a day out banks the XP shown).
      outFrom: () => _minuteOf(now),
      breakAt: () => null,
    );
    _startSeen = true;
    return true;
  }

  /// His days out, made right for [now] (Round 63): a finished one's XP
  /// banked; today's started if it's time and he could go: at 12:00 if he
  /// had energy then (charging or not), or else when he's back on before
  /// 17:00 (a battery). Run before anything that changes his energy, so
  /// his energy at 12:00 is still known.
  void _settle(DateTime now) {
    _settleQuest(now);
    if (!state.adventurer) return;
    final from = state.outFrom;
    if (from != null && !now.isBefore(PipAdventure.endOf(from))) {
      state = state.copyWith(
        minutesOut: state.minutesOut +
            PipAdventure.minutesBetween(from, PipAdventure.endOf(from)),
        outFrom: () => null,
        breakAt: () => null,
      );
    }
    final today = dayKey(now);
    if (state.outDay == today) return;
    _settleMissed(now);
    final start = PipAdventure.startOf(now);
    if (now.isBefore(start)) return;
    DateTime? out;
    final since = state.energyAt ?? now;
    if (PipTrip.busDay(_dates(), now)) {
      // Round 67: on the bus that day: no adventure shown, its XP all
      // the same.
      out = start;
    } else if (!since.isAfter(start) && levelAt(start) > 0) {
      out = start;
    } else if (now.hour < PipAdventure.lastStartHour && levelAt(now) > 0) {
      out = _minuteOf(now);
    }
    if (out == null) return;
    state = state.copyWith(
      outDay: () => today,
      outFrom: () => out,
      breakAt: () => null,
    );
    // Setting off now: seen (Round 66: his break waits).
    if (now.difference(out) < const Duration(minutes: 1)) _startSeen = true;
    // Not seen till after 18:00: the whole day out at once.
    if (!now.isBefore(PipAdventure.endOf(out))) _settle(now);
  }

  static DateTime _minuteOf(DateTime t) =>
      DateTime(t.year, t.month, t.day, t.hour, t.minute);

  /// When he was last looked at, and whether he was seen setting off
  /// today and not left unseen since (Round 66; in memory: the app's
  /// first look is a fresh one). Then his break waits.
  DateTime? _seenAt;
  bool _startSeen = false;

  /// He's looked at [now] (his room, every second while it's shown).
  void lookedAt(DateTime now) {
    final last = _seenAt;
    if (last == null || now.difference(last) >= PipAdventure.unseenFor) {
      _startSeen = false;
    }
    _seenAt = now;
  }

  /// The days between his last day out and [now]'s that nobody looked in
  /// on (Round 67): each a whole day out if he could go at 12:00 (energy
  /// then, by what's known; he can't power down once out) or was on his
  /// ski trip's bus; else none. Each such day is then done with.
  void _settleMissed(DateTime now) {
    final last = state.outDay;
    if (last == null) return;
    final parts = last.split('-').map(int.parse).toList();
    var day = DateTime(parts[0], parts[1], parts[2] + 1);
    final today = DateTime(now.year, now.month, now.day);
    var minutes = state.minutesOut;
    String? done;
    for (var i = 0; i < 400 && day.isBefore(today); i++) {
      final start = PipAdventure.startOf(day);
      final since = state.energyAt ?? start;
      if (PipTrip.busDay(_dates(), day) ||
          (!since.isAfter(start) && levelAt(start) > 0)) {
        minutes += PipAdventure.minutesPerDay;
      }
      done = dayKey(day);
      day = DateTime(day.year, day.month, day.day + 1);
    }
    if (done != null) {
      state = state.copyWith(minutesOut: minutes, outDay: () => done);
    }
  }

  /// His break starts at [now] if it's due (Round 64: looked at between
  /// 14:00 and 16:00, none had today; Round 66: if he was seen setting
  /// off, only once he's gone unseen five minutes).
  void breakIfDue(DateTime now) {
    final from = state.outFrom;
    if (from == null ||
        state.breakAt != null ||
        !outAt(now) ||
        !PipAdventure.breakDueAt(now, from, startSeen: _startSeen)) {
      return;
    }
    state = state.copyWith(breakAt: () => now);
  }

  /// The batteries due by [now] (Round 45: every few hours on the clock,
  /// piling up while away, up to 3 held).
  void collect(DateTime now) {
    if (!state.hatched) return;
    _settle(now);
    final next = state.nextBatteryAt;
    if (next == null) {
      state = state.copyWith(nextBatteryAt: () => PipEnergy.nextBattery(now));
      return;
    }
    final (held, after) = PipEnergy.batteriesAt(state.batteries, next, now);
    if (after != next) {
      state = state.copyWith(batteries: held, nextBatteryAt: () => after);
    }
  }

  /// What to show of him at [now].
  PipShow showAt(DateTime now) => pipShowAt(
        now,
        level: levelAt(now),
        offSeen: state.offSeen,
        sleepSeen: state.sleepSeen,
        wakeSeen: state.wakeSeen,
        wokenAt: state.wokenAt,
      );

  /// Round 77: three taps on him asleep at [now]: woken (true), if he may
  /// be (`PipEnergy.mayWakeAt`; not on his trip's bus).
  bool wake(DateTime now) {
    _settle(now);
    if (!mayWakeAt(now)) return false;
    state = state.copyWith(wokenAt: () => now);
    return true;
  }

  /// Whether three taps would wake him at [now] (Pip Home says so).
  bool mayWakeAt(DateTime now) =>
      state.hatched &&
      showAt(now) == PipShow.asleep &&
      PipEnergy.mayWakeAt(state.wokenAt, now) &&
      PipTrip.at(_dates(), now).leg == null;

  /// Woken at night and still up at [now]: drowsy.
  bool drowsyAt(DateTime now) => PipEnergy.drowsyAt(state.wokenAt, now);

  /// [show] was shown at [now]: remembered, so it isn't played again.
  void shown(PipShow show, DateTime now) {
    _settle(now);
    switch (show) {
      case PipShow.powerOff || PipShow.off:
        if (!state.offSeen) {
          // Empty now: kept so, whatever the clock does.
          state = state.copyWith(
            offSeen: true,
            energy: 0,
            energyAt: () => now,
          );
        }
      case PipShow.fallAsleep:
        state = state.copyWith(sleepSeen: () => dayKey(now));
      case PipShow.wakeUp:
        state = state.copyWith(wakeSeen: () => dayKey(now));
      case PipShow.awake || PipShow.asleep:
        break;
    }
  }

  /// Why a battery can't be given at [now], or null if it can: none
  /// held, he's full, or he's asleep (off, he can have one: it turns him
  /// back on).
  PipRefusal? refusalAt(DateTime now) {
    if (!state.hatched) return PipRefusal.egg;
    if (state.batteries == 0) return PipRefusal.noBatteries;
    if (segmentsAt(now) >= 3) return PipRefusal.full;
    final show = showAt(now);
    if (show == PipShow.asleep) return PipRefusal.asleep;
    // Round 67: on his ski trip's bus, nothing.
    if (PipTrip.at(_dates(), now).leg != null) return PipRefusal.travelling;
    // Round 44: plugged in (at his station), not now.
    // Round 65: not while he's out (he isn't at his station then).
    if (_charging && show != PipShow.off && !outAt(now)) {
      return PipRefusal.charging;
    }
    return null;
  }

  /// Gives him a battery at [now], if he can have one: a segment more
  /// (up to full), and on again if he was off. True if given.
  bool giveBattery(DateTime now) {
    _settle(now);
    if (refusalAt(now) != null) return false;
    state = state.copyWith(
      batteries: state.batteries - 1,
      energy: math.min(PipLife.fullEnergy, levelAt(now) + 1),
      energyAt: () => now,
      offSeen: false,
    );
    // Round 63: back on before 17:00, he goes out.
    _settle(now);
    return true;
  }

  /// A segment from his station at [now] (Round 58): a segment more, up
  /// to full, and on again if he was off. False if he's full (or an egg).
  bool chargeTick(DateTime now) {
    if (!state.hatched) return false;
    _settle(now);
    final level = levelAt(now);
    if (level >= PipLife.fullEnergy) return false;
    state = state.copyWith(
      energy: math.min(PipLife.fullEnergy, level + 1),
      energyAt: () => now,
      offSeen: false,
    );
    _settle(now);
    return true;
  }

  // ---- Quests (Round 125, docs/QUESTS_SPEC.md) ----

  /// The quest under way, or null.
  QuestScript? get quest => Quests.byId(state.questId);

  /// The quest offered now: the next in the chain, when none is under
  /// way (an egg has none).
  QuestScript? get questOffered => !state.hatched || state.questId != null
      ? null
      : Quests.nextAfter(state.questsDone.map((d) => d.id));

  /// Round 128: his house is built (he lives in it).
  bool get houseBuilt => state.questsDone.any((d) => d.id == Quests.house.id);

  /// Away on a ski trip at [t] (on the bus or at the resort): no quest
  /// work then.
  bool _awayAt(DateTime t) {
    final trip = PipTrip.at(_dates(), t);
    return trip.leg != null || trip.snowy;
  }

  /// Whether the offered quest can be started at [now]: in quest hours,
  /// not away.
  bool canStartQuestAt(DateTime now) =>
      questOffered != null && PipQuest.canStartAt(now) && !_awayAt(now);

  /// Starts the offered quest at [now] (spec 2: only in quest hours; it
  /// can't be stopped). True if it was.
  bool startQuest(DateTime now) {
    _settle(now);
    final next = questOffered;
    if (next == null || !canStartQuestAt(now)) return false;
    final at = _minuteOf(now);
    state = state.copyWith(
      questId: () => next.id,
      questFrom: () => at,
      questMinutes: 0,
      questCountedTo: () => at,
    );
    return true;
  }

  /// The work minutes from [from] to [to] (spec 4): quest hours, less
  /// those he was powered down or away. His energy only drains between
  /// the moments it changes (each settles first), so within a window he's
  /// on until he empties, then off to its end. Also returns when the
  /// [cap]th minute was worked, if it was.
  (int, DateTime?) _workedBetween(DateTime from, DateTime to, {int? cap}) {
    var worked = 0;
    for (final (a, b) in PipQuest.windowsBetween(from, to)) {
      final length = b.difference(a).inMinutes;
      if (length <= 0) continue;
      // The first minute he's off in it (binary search: his level only
      // falls), or the window's end.
      var lo = 0, hi = length;
      while (lo < hi) {
        final mid = (lo + hi) ~/ 2;
        if (levelAt(a.add(Duration(minutes: mid))) <= 0) {
          hi = mid;
        } else {
          lo = mid + 1;
        }
      }
      // Away is checked a few minutes at a time (trips change by hours).
      for (var m = 0; m < lo; m += 5) {
        final t = a.add(Duration(minutes: m));
        if (_awayAt(t)) continue;
        final chunk = math.min(5, lo - m);
        if (cap != null && worked + chunk >= cap) {
          return (cap, t.add(Duration(minutes: cap - worked)));
        }
        worked += chunk;
      }
    }
    return (worked, null);
  }

  /// His quest's work brought up to [now]; done, it's finished (with the
  /// moment its last minute was worked) and the next can be offered.
  void _settleQuest(DateTime now) {
    final script = quest;
    if (script == null) return;
    final from = state.questCountedTo ?? state.questFrom ?? now;
    // Counted in whole minutes (quest hours start on the minute), so the
    // file's written at most once a minute, and only for work done.
    final to = _minuteOf(now);
    if (!to.isAfter(from)) return; // the clock went back: nothing
    final left = script.totalMinutes - state.questMinutes;
    final (worked, doneAt) = _workedBetween(from, to, cap: left);
    if (doneAt != null) {
      state = state.copyWith(
        questId: () => null,
        questFrom: () => null,
        questMinutes: 0,
        questCountedTo: () => null,
        questsDone: [...state.questsDone, PipQuestDone(script.id, doneAt)],
      );
      return;
    }
    // Nothing worked and no quest hours passed: nothing to keep (outside
    // them, so the file isn't written each minute). Quest hours passed
    // with nothing worked (powered down) are kept counted: a battery later
    // mustn't make them work.
    if (worked == 0 && PipQuest.windowsBetween(from, to).isEmpty) return;
    state = state.copyWith(
      questMinutes: state.questMinutes + worked,
      questCountedTo: () => to,
    );
  }

  /// His quest's work at [now] (what's stored and what's come since),
  /// without changing anything: where it is, or null if none is under
  /// way.
  QuestAt? questAt(DateTime now) {
    final script = quest;
    if (script == null) return null;
    final from = state.questCountedTo ?? state.questFrom ?? now;
    final (since, _) =
        now.isAfter(from) ? _workedBetween(from, now) : (0, null);
    return script.at(state.questMinutes + since);
  }

  /// Whether he's at his quest's work at [now]: one under way, quest
  /// hours, on, not away.
  bool questWorkingAt(DateTime now) =>
      quest != null &&
      PipQuest.inHoursAt(now) &&
      levelAt(now) > 0 &&
      !_awayAt(now);

  /// Brings his quest up to [now] (the app looking in).
  void settleQuest(DateTime now) => _settleQuest(now);

  /// Replaces him (restoring a backup): one from before Round 37 starts
  /// full from now.
  void replace(PipLife pip) => state = _started(pip);
}

/// Why he can't have a battery now.
enum PipRefusal { egg, noBatteries, full, asleep, charging, travelling }

final pipLifeProvider = StateNotifierProvider<PipLifeNotifier, PipLife>(
  (ref) => PipLifeNotifier(
    ref.watch(appStorageProvider),
    clock: ref.watch(clockProvider),
    dates: () => ref.read(datesProvider),
  ),
);

/// His XP as last collected while he's watched fighting (Round 73: it
/// goes up as he strikes bugs, not by the clock), and when his room last
/// kept it up; null: not watched, it shows as it is.
typedef PipHeldXp = ({int xp, DateTime at});
final pipHeldXpProvider = StateProvider<PipHeldXp?>((ref) => null);

/// His XP as shown now (Round 73): [PipLifeNotifier.shownXpAt].
int pipShownXp(WidgetRef ref, DateTime now) => ref
    .read(pipLifeProvider.notifier)
    .shownXpAt(now, ref.watch(pipHeldXpProvider));

/// Pip's life as his room sees it (Round 37): what to show, what was
/// shown, a battery given.
class _Link implements PipLink {
  final Ref _ref;

  _Link(this._ref);

  PipLifeNotifier get _pip => _ref.read(pipLifeProvider.notifier);
  DateTime get _now => _ref.read(clockProvider)();

  @override
  (PipShow, int) look() {
    // Plugged in or not first (Round 44): it decides his energy.
    _ref.read(pipPowerProvider.notifier).refresh();
    final now = _now;
    _pip.lookedAt(now);
    _pip.collect(now);
    return (_pip.showAt(now), _pip.segmentsAt(now));
  }

  @override
  void shown(PipShow show) => _pip.shown(show, _now);

  @override
  bool giveBattery() => _pip.giveBattery(_now);

  @override
  bool wake() => _pip.wake(_now);

  @override
  bool get drowsy => _pip.drowsyAt(_now);

  @override
  bool chargeTick() => _pip.chargeTick(_now);

  @override
  PipTripNow trip() => PipTrip.at(_ref.read(datesProvider), _now);

  @override
  PipQuestNow? questNow() {
    final now = _now;
    if (!_pip.questWorkingAt(now)) return null;
    final at = _pip.questAt(now);
    if (at == null) return null;
    return (
      at: at,
      seconds: at.into * 60 + now.second + now.millisecond / 1000,
    );
  }

  @override
  bool homeNow() {
    final now = _now;
    return _pip.houseBuilt && !PipQuest.fieldTimeAt(now);
  }

  @override
  PipOut? outing() {
    final now = _now;
    if (!_pip.outAt(now)) return null;
    // Round 67: a day on the ski trip's bus: its XP, no adventure shown.
    if (PipTrip.busDay(_ref.read(datesProvider), now)) return null;
    _pip.breakIfDue(now);
    final at = _ref.read(pipLifeProvider).breakAt;
    if (at == null || !_pip.onBreakAt(now)) {
      return (onBreak: false, breakDone: 0);
    }
    final done =
        now.difference(at).inSeconds / PipAdventure.breakLength.inSeconds;
    return (onBreak: true, breakDone: done.clamp(0.0, 1.0));
  }

  @override
  int get level =>
      PipAdventure.levelFor(_pip.shownXpAt(_now, _ref.read(pipHeldXpProvider)));

  @override
  void fighting(bool on) {
    final held = _ref.read(pipHeldXpProvider.notifier);
    if (!on) {
      if (held.state != null) held.state = null;
      return;
    }
    // Kept up: what's shown stays as it is till the next bug.
    final now = _now;
    held.state = (xp: _pip.shownXpAt(now, held.state), at: now);
  }

  @override
  int defeated({bool boss = false}) {
    final now = _now;
    final held = _ref.read(pipHeldXpProvider.notifier);
    final before = _pip.shownXpAt(now, held.state);
    if (boss) _pip.bossBeaten(now);
    if (held.state != null) held.state = (xp: _pip.xpAt(now), at: now);
    return _pip.shownXpAt(now, held.state) - before;
  }

  @override
  bool get bossDue => _pip.bossDueAt(_now);

  @override
  double? outRun() => _pip.runningAt(_now);

  @override
  bool? get plugged => _ref.read(pipPowerProvider.notifier).known
      ? _ref.read(pipPowerProvider)
      : null;

  @override
  DateTime get now => _now;

  @override
  bool get medicineDue {
    final now = _now;
    return !_ref.read(preferencesProvider).medicinePausedOn(dayOf(now)) &&
        doseDue(_ref.read(medicineProvider), now);
  }

  @override
  DateTime? get recipeReadAt => _ref.read(recipeReadProvider);

  @override
  PipHat? get hatToday {
    final born = _ref.read(pipLifeProvider).born;
    return pipHatOn(dayOf(_now),
        seed: born == null ? 0 : born.millisecondsSinceEpoch ~/ 1000);
  }

  @override
  bool get partyHat {
    final today = dayOf(_now);
    return _ref.read(datesProvider).birthdayOn(today) ||
        _ref.read(pipLifeProvider).birthdayOn(today);
  }

  @override
  bool notifiedBetween(DateTime from, DateTime to) => _ref
      .read(notificationLogProvider)
      .scheduled
      .any((n) => n.at.isAfter(from) && !n.at.isAfter(to));
}

/// Whether the phone is plugged in (Round 44: Pip's charging station):
/// asked of Android at first and again while he's looked at (every few
/// seconds at most: so also when the app comes back), and told as it
/// changes while the app is open. Kept in his life (he can't lose power
/// meanwhile) and in this phone's preferences (for after a restart).
class PipPowerNotifier extends StateNotifier<bool> {
  final Ref _ref;
  StreamSubscription<bool>? _changes;

  PipPowerNotifier(this._ref)
      : super(_ref.read(preferencesProvider).pipPlugged) {
    _ref.read(pipLifeProvider.notifier).resumeCharging(state);
    final source = _ref.read(powerSourceProvider);
    _changes = source.changes.listen(_set);
    _ask();
  }

  /// Since it was last asked (a real clock, whatever the app's).
  final _sinceAsked = Stopwatch()..start();
  static const askEvery = Duration(seconds: 5);

  /// Asks again if it's been a while (the app may have been away).
  void refresh() {
    if (_sinceAsked.elapsed < askEvery) return;
    _ask();
  }

  Future<void> _ask() async {
    _sinceAsked.reset();
    final plugged = await _ref.read(powerSourceProvider).plugged();
    if (mounted) _set(plugged);
  }

  /// Android has said, this run (Round 64).
  bool get known => _known;
  bool _known = false;

  void _set(bool plugged) {
    _known = true;
    final now = _ref.read(clockProvider)();
    _ref.read(pipLifeProvider.notifier).setCharging(plugged, now);
    _ref.read(preferencesProvider.notifier).setPipPlugged(plugged);
    state = plugged;
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }
}

final pipPowerProvider = StateNotifierProvider<PipPowerNotifier, bool>(
  PipPowerNotifier.new,
);

final pipLinkProvider = Provider<PipLink>((ref) => _Link(ref));
