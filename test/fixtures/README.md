# Compatibility fixtures

Files exactly as the app wrote them, one folder per format version. They
are **frozen**: never edit or regenerate them. When a format changes, add
a new folder (`v2/`, …) with files from the new version and keep the old
ones — `test/data/storage_compatibility_test.dart` checks that the current
app still reads every version, so an update can never lose existing data.

- `v1/storage/` — `notes.json`, `shop.json`, `security.json` from the app's
  data folder (master password of the sample: `fixture password`). The
  second note uses local times without a zone, as the app writes them.
- `v1/backup-plain.json`, `v1/backup-encrypted.json` — exported backups
  (encrypted with `fixture password`).
- `v2/storage/` — as v1, plus a **locked note** (`Bank 🔒`, content sealed
  with the data key) and the master password record holding that data
  key, wrapped (password: `fixture password`).
- `v2/backup-plain.json`, `v2/backup-encrypted.json` — backups of the v2
  sample, including the locked note (still encrypted) and the master
  password record its key needs (password: `fixture password`).
- `v2/storage/planner.json` — planner tasks (added with the planner; the
  storage format is still 2: it's a new file).
- `v3/backup-plain.json`, `v3/backup-encrypted.json` — backups with planner
  tasks, a locked note and its key record (password: `fixture password`).
- `v2/storage/counters.json`, `v3/backup-with-counters.json` — counters
  (added with them, before v3 was released; the other v3 backups have
  none, which v3 allows).
- `v3/storage/planner.json` — planner tasks with start and end times
  (planner.json has its own version, 3; the other files are still 2).
- `v4/backup-plain.json` — backup with timed planner tasks and the Džoni
  count.
- `v5/storage/planner.json` — planner tasks, one with a colour
  (planner.json version 4).
- `v5/storage/routines.json` — routines (version 1): Gym Mon/Wed/Fri
  18:00–19:00 for good, in green; Read 📚 every day 22:00–23:00 until the
  end of 2026; on Mon 12 Oct Gym is skipped and Read ticked off.
- `v5/backup-plain.json` — backup (version 5) with those tasks and
  routines.
