# Roadmap

What is planned beyond the current app. The requirements and their status
are in [REQUIREMENTS.md](REQUIREMENTS.md); what each release changed is in
[CHANGELOG.md](../CHANGELOG.md).

## Way of working

- Each change is small and complete on its own: code, tests,
  `flutter analyze` clean, and the documentation updated in the same
  commit. No half-finished features on `main`.
- Every change adds or updates tests. Anything touching storage,
  import/export or encryption gets round-trip tests with real files,
  including failure cases.
- A change to the app ends with a release: version bump, `CHANGELOG.md`
  section, then the Release workflow ([RELEASING.md](RELEASING.md)).

## Planned

### Cloud backup (D5)

Backups to a self-hosted service, its connection details entered in the
app (never hard-coded), with the existing encrypted backup format as the
payload. On hold until the service exists.

### Page organizer (O10)

A quick-access menu with chosen pages, opened from the side.

### Page ideas

Candidates for new Hub pages, each to be specified before it is built:

- **Gifts**: gift ideas per person, linked to People and to birthdays in
  Dates; past gifts remembered.
- **Timers**: several named countdowns at once, with notifications; a
  recipe step with a duration starts one.
- **Lent and borrowed**: what is lent to or borrowed from whom, linked to
  People, with an optional reminder.
- **Plants**: watering intervals, a "watered" action and reminders.
- **Documents** (agreed, [DOCUMENTS_SPEC.md](DOCUMENTS_SPEC.md)):
  identity documents, receipts with warranties, barcodes and tickets, with
  pictures; optionally encrypted by its page lock; backups as one zip.
- **Parking**: where the car is, with a timer for the meter.

### Pip

- Item and phrase ideas for his adventures.
- The next quest after the house.

## Technical debt

- The Android toolchain is the one Flutter 3.29 generated (Kotlin 1.8.22,
  AGP 8.1, Gradle 8.3). New plugins must be picked at versions that build
  with it (e.g. `package_info_plus` 8.x). Upgrade Flutter and the Android
  toolchain together, as one dedicated change, when plugins require it.
- Two APIs carry `// ignore: deprecated_member_use` because they are only
  deprecated on newer Flutter (`onReorder`, `TickerMode.of`). Switch to
  `onReorderItem` / `TickerMode.valuesOf` when upgrading Flutter.
