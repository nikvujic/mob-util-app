# Backlog

Internal checklist of known gaps and follow-ups, highest priority first.
Feature requirements live in [REQUIREMENTS.md](REQUIREMENTS.md).

## P0 — needed before relying on the app day-to-day

- [ ] **Local persistence (G6).** All data (notes, note order, shop items and
      sections/order) is in memory only and is lost when the app is closed.
      Save on every change and load on start; must survive app restarts and
      updates. Add tests that round-trip the stored data.
- [ ] **Export / import (N8, extended to all data).** Failsafe for a deleted
      app or a new device: export everything (notes + shop) to a single file
      the user can save/share, and import it back. Import must be safe —
      validate the file and confirm before replacing existing data.

## P1

- [ ] **To Do page (T2).** Requirements to be specified.

## Notes / housekeeping

- [ ] Target Flutter version is ~3.29 (per `pubspec.lock`). Two APIs we use
      are deprecated on newer Flutter (`ReorderableList.onReorder`,
      `TickerMode.of`); they carry `// ignore: deprecated_member_use` with a
      comment. Switch to `onReorderItem` / `TickerMode.valuesOf` when the
      project's Flutter is upgraded.
- [ ] Android native build output (`android/app/.cxx/`) is committed; add it
      to `.gitignore` and remove it from the repo.
