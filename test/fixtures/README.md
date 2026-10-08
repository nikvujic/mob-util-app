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
