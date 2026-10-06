# Backlog

Internal checklist of known gaps and follow-ups, highest priority first.
Feature requirements live in [REQUIREMENTS.md](REQUIREMENTS.md).

## P0 — needed before relying on the app day-to-day

- [x] **Local persistence (G6).** Notes, note order, shop items and their
      sections/order are saved to JSON files and loaded on start.
- [ ] **Export / import (N8, extended to all data).** Failsafe for a deleted
      app or a new device: export everything (notes + shop) to a single file
      the user can save/share, and import it back. Import must be safe —
      validate the file and confirm before replacing existing data.

- [ ] **Verify persistence on a real Android device**: add data, force-stop
      the app, reopen; also after an app update (`flutter install` over the
      existing app).

## P1

- [ ] **To Do page (T2).** Requirements to be specified.

## Notes / housekeeping

- [ ] Target Flutter version is ~3.29 (per `pubspec.lock`). Two APIs we use
      are deprecated on newer Flutter (`ReorderableList.onReorder`,
      `TickerMode.of`); they carry `// ignore: deprecated_member_use` with a
      comment. Switch to `onReorderItem` / `TickerMode.valuesOf` when the
      project's Flutter is upgraded.
- [ ] Web build keeps data in memory only (`path_provider` has no web
      support). Fine while web is only used for previews.
- [ ] Android native build output (`android/app/.cxx/`) is committed; add it
      to `.gitignore` and remove it from the repo.
