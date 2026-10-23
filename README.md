# The App

A personal productivity app for Android, built with Flutter. It brings
everyday tools together in one offline-first app: notes, shopping lists, a
day planner, and a hub of smaller utilities. A pixel-art companion, Pip,
lives in the navigation drawer and reacts to how the phone is used.

All data stays on the device. The only network access is an optional weather
lookup, and it can be switched off.

## Features

**Core sections**

- **Notes**: rich-text notes with lightweight Markdown (headings, lists,
  checkboxes, multi-line code blocks), custom ordering and multi-select.
- **Shop**: "to buy" and "items" lists with quantities, search, sorting and
  drag-to-reorder.
- **Planner**: a day timeline of tasks and recurring routines, with overlap
  detection, "find free time", reminders and moving blocks between days.

**Hub tools**

- **Medicine**: dose schedules by weekday, a dose history with a calendar
  view, lifetime totals, and reminders with optional follow-ups.
- **Recipes and Ingredients**: recipes with sections and quantities, and a
  shared ingredient catalogue that feeds the shopping list.
- **Food**: a daily meal log with ratings and statistics.
- **Dates**: birthdays, anniversaries and trips, with a month calendar and
  reminders.
- **Subscriptions**: recurring payments, with reminders before each renewal.
- **Packing**: reusable packing lists with sections, counts, check-off mode
  and copying between lists.
- **Counters** and **Placard** (full-screen text) for quick everyday use.
- **Morning music**: a native alarm that starts the music player at a set
  time, volume and set of weekdays, even when the app is closed.

**Pip, the companion**

Pip is a pixel-art character drawn with a `CustomPainter`. His behaviour
comes from a simulation that steps forward every frame. He has energy that
follows the phone's battery and charging state, and he sleeps at night. His
scene follows the live weather, the season and the time of day. Random
events, daily "adventures" with experience levels, and haptic feedback make
him feel alive without getting in the way.

**Privacy and data safety**

- Sections can be locked behind a password or the fingerprint.
- Encrypted backups, made by hand or automatically to a chosen folder, with
  full or partial restore.
- Notifications per section, with private mode and a notification history.

## Tech stack

| Area | Choice |
|------|--------|
| Framework | Flutter 3.29, Dart 3 |
| State management | Riverpod 2 (`StateNotifier` providers) |
| Persistence | JSON documents on local storage, with atomic writes |
| Encryption | Argon2id key derivation and AES-256-GCM (`cryptography`) |
| Biometrics | `biometric_storage` (Android Keystore) |
| Notifications | `flutter_local_notifications` with `timezone` |
| Native integration | Kotlin platform channels: power state, alarms, folder access, sounds, screen |
| Weather | Open-Meteo REST API (optional) |
| CI/CD | GitHub Actions: format, analyze, test and build on every push; signed release APKs on demand |

## Architecture

The code follows a strict layered architecture. Dependencies point one way
only, and an architecture test enforces the rules on every test run.

```
main.dart ──► app/ ──► pages/<feature>/ ──► widgets/
                │            │
                │            ▼
                └──────► providers/ ──► data/ ──► models/
                                                     ▲
                core/  (shared foundations)
```

| Layer | Responsibility |
|-------|----------------|
| `models/` | Immutable value types with JSON serialisation. No Flutter dependency. |
| `data/` | Persistence, backup, platform channels and HTTP. The only layer that touches `dart:io` or platform plugins. |
| `providers/` | Application state and business rules as Riverpod notifiers. Every change is persisted through `data/`. |
| `pages/<feature>/` | Feature UI. Features are isolated from each other and navigate by named routes. |
| `widgets/` | Reusable, feature-agnostic UI components. |
| `core/` | Theme, formatting, cryptography, routing and the pure simulation logic for Pip. |
| `app/` | The app shell: navigation, drawer, section locking. |

Key design decisions:

- **Offline first, with explicit data versions.** Each store carries its own
  format version and migrates older data on load. Frozen fixtures from
  every past version, checked against SHA-256 hashes, guarantee that old
  data and backups always load.
- **Crash-safe storage.** Writes go to a temporary file and are moved into
  place with an atomic rename. Writes are serialised and merged, so the
  latest state always wins.
- **Encryption at rest for locked data.** The key is derived with Argon2id,
  and the KDF parameters are stored with the data so they can be
  strengthened later. Data is sealed with AES-256-GCM, so tampering or a
  wrong password is always detected and never produces garbage. Passwords
  are never stored.
- **Deterministic simulation.** Pip's behaviour is a pure state machine in
  `core/`, stepped by a ticker and seeded with an injectable random source,
  so every animation can be unit-tested frame by frame.
- **Theming through tokens.** All colours come from the active theme's
  palette, enforced by a lint-style test, so every screen supports every
  light and dark theme.

More detail is in [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).

## Quality

- Over 2,300 automated tests (unit, widget and integration-style) across 160+
  files.
- Architecture tests that enforce layer boundaries, import rules, theming
  and plugin confinement.
- Design tests based on Android's accessibility guidelines: 48 dp tap
  targets, screen-reader labels and text contrast.
- Storage compatibility tests against frozen fixtures of every data version.
- CI requires clean formatting and static analysis, and a passing test
  suite, before a build.

## Project structure

```
lib/          application code (layers above)
test/         tests, mirroring lib/, plus fixtures/ for data versions
android/      Android host app and Kotlin platform channels
assets/       icons, fonts, bundled texts
docs/         architecture, requirements, specs and release process
```

## Getting started

Requirements: Flutter 3.29 and an Android SDK (API 23 or newer).

```sh
flutter pub get
flutter run            # on a connected device or emulator
flutter test           # full test suite
flutter analyze        # static analysis
```

Releases are built by the `release.yml` workflow from the version in
`pubspec.yaml`. See [docs/RELEASING.md](docs/RELEASING.md).

## Documentation

- [Architecture](docs/ARCHITECTURE.md)
- [Requirements](docs/REQUIREMENTS.md)
- [Changelog](CHANGELOG.md)
- Feature specs: [Recipes](docs/RECIPES_SPEC.md), [Dates](docs/DATES_SPEC.md),
  [Subscriptions](docs/SUBSCRIPTIONS_SPEC.md),
  [Adventures](docs/ADVENTURES_SPEC.md)
