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
  count (that page is gone; the count is now ignored).
- `v5/storage/planner.json` — planner tasks, one with a colour
  (planner.json version 4).
- `v5/storage/routines.json` — routines (version 1): Gym Mon/Wed/Fri
  18:00–19:00 for good, in green; Read 📚 every day 22:00–23:00 until the
  end of 2026; on Mon 12 Oct Gym is skipped and Read ticked off.
- `v5/backup-plain.json` — backup (version 5) with those tasks and
  routines.
- `v6/storage/pins.json` — planner reminders (P14, version 1): "Call mum"
  on Mon 12 Oct at 10:30 and "Take out the bins 🗑" on Tue 13 Oct at
  20:00.
- `v6/backup-plain.json` — backup (version 6) with one task (Work) and
  those reminders.
- `v7/storage/planner.json` (planner.json version 5) and
  `v7/storage/routines.json` (routines.json version 2) — a task and a
  routine with a description (P20); "Dentist" has two lines, "Groceries"
  none; the routine "Pills 💊" is 5 minutes long.
- `v7/backup-plain.json` — backup (version 7) with those.
- `v8/storage/shop.json` — shop items with quantities (S7; shop.json now
  has its own version, 3): Milk ×2, Flour 1.5 kg, Saffron 🌼 0.5 g (its
  count of 4 kept from before it was switched to weight), and Bread
  (bought, no quantity shown, a count of 3 kept).
- `v8/backup-plain.json` — backup (version 8) with those items.
- `v8/storage/layout.json` — where the pages go (O9, layout.json version
  1, from before the Hub's rename: its order under `other`),
  `["counters"]`. Added after 0.21.0; not in backups
  (a setting, like the theme).
- `v9/storage/placard.json` — Placard (O4, placard.json version 1): "Why so
  quiet? 🤐", count 41.
- `v9/backup-plain.json` — backup (version 9) with that Placard and one
  counter (Push-ups, 12).
- `v10/storage/counters.json` — counters with options (O5; counters.json
  now has its own version, 3): Push-ups 12 (no options), Water 💧 750 by
  250 in blue between 0 and 3000, Floor −2 with a min of −3.
- `v10/backup-plain.json` — backup (version 10) with those counters.
- `v11/storage/medicine.json` — the medicine tracker (O6, medicine.json
  version 1): Vitamin D 💊 once a day (08:00) from 1 Oct for good, and
  Antibiotic twice a day (08:00, 20:00) 10–16 Oct; on 11 Oct the Vitamin D
  was taken at 08:04 and the Antibiotic's evening dose at 20:31.
- `v11/backup-plain.json` — backup (version 11) with that.
- `v12/storage/medicine.json` — dose states (O13, medicine.json version
  2): Coffee ☕ from 1 Jul, taken 1 Jul (filled in, no time), missed 2
  Jul, not sure 3 Jul, taken 12 Oct at 07:55.
- `v12/backup-plain.json` — backup (version 12) with that.
- `v13/storage/medicine.json` — remind again per medicine (Round 16,
  medicine.json version 3): Iron 🩸 twice a day (08:00, 20:00) from 1
  Oct, reminding again 4 h later (`followUp` 240); Vitamin C at 09:00
  with none; Iron's morning dose taken 12 Oct at 08:02.
- `v13/backup-plain.json` — backup (version 13) with that.
- `v13/storage/settings.json` — locks (settings.json still version 2;
  `pageLocks` added in Round 21, after 0.26.0): the Shop section locked,
  and the Hub's Placard and Medicine pages (O7). Not in backups.
- `v14/storage/medicine.json` — important medicines (Round 24,
  medicine.json version 4): Heart pills ❤️ twice a day (08:00, 20:00)
  from 1 Oct, **important**; Vitamin C at 09:00, not; the Heart pills'
  morning dose taken 12 Oct at 08:01.
- `v14/backup-plain.json` — backup (version 14) with that.
- `v15/storage/todo.json` — the to-do note's list (Round 28, todo.json
  version 1): "Call the dentist 🦷", "Pay the bills, šta god", "Water
  the plants", in that order (ids t1–t3).
- `v15/backup-plain.json` — backup (version 15) with that.
- `v16/storage/todo.json` — done to-dos (Round 30, todo.json version 2):
  as v15, "Pay the bills, šta god" done.
- `v16/backup-plain.json` — backup (version 16) with that.
- `v17/storage/pip.json` — Pip, the pet (Round 34, pip.json version 1):
  hatched 13 Oct 2026 20:30 UTC, named "Bip 2".
- `v17/backup-plain.json` — backup (version 17) with him.
- `v18/storage/pip.json` — Pip with his energy (Round 37, pip.json
  version 2): "Bip 3", hatched 13 Oct 2026 20:30 UTC, energy 1.5 at 14
  Oct 06:00 UTC, 2 batteries held, the next at 09:15 UTC; seen falling
  asleep the night of 13 Oct; not seen off, nor waking.
- `v18/backup-plain.json` — backup (version 18) with him.
- `v19/storage/medicine.json` — a medicine on some weekdays only (Round
  40, medicine.json version 5): Vitamin D 💊 at 08:00 on Mon, Wed, Fri
  (taken Mon 12 Oct 06:30 UTC), and Iron at 20:00 every day.
- `v19/backup-plain.json` — backup (version 19) with them.
- `v20/storage/recipes.json` — recipes (Round 42, recipes.json version
  1): "Palačinke 🥞", 25 min, breakfast, with Flour 200 g, Milk 300 ml,
  Eggs 🥚 2 (each from the list: i1, i3, i4) and Salt "a pinch" (not
  from the list), a Markdown method; then "Tea", with nothing set.
- `v20/storage/ingredients.json` — the ingredients list (Round 42,
  ingredients.json version 1): Baking (Flour, Sugar), Dairy (Milk, Eggs
  🥚).
- `v20/backup-plain.json` — backup (version 20) with both.
- `v21/storage/todo.json` — waiting to-dos (Round 45, todo.json version
  3): "Call the dentist 🦷", "Pay the bills, šta god" (done), "Parcel
  from Ana 📦" (**waiting**), "Water the plants" (ids t1–t4).
- `v21/storage/settings.json` — the to-do note locked (Round 45,
  `todoLocked`; settings.json still version 2), no other locks. Not in
  backups.
- `v21/backup-plain.json` — backup (version 21) with the to-dos.
- `v22/storage/food.json` — the food tracker (Round 46, food.json
  version 1): foods "Burek 🥟" (gluten, fried), "Jogurt" (dairy), "Kafa"
  (caffeine); breakfast 14 Oct 06:30 UTC with Burek and Jogurt, rated
  **bad**, bloating and heartburn, note "Previše, šta god"; a snack at
  11:00 UTC with Kafa and "Keks" (not from the list), not rated.
- `v22/backup-plain.json` — backup (version 22) with it.
- `v23/storage/dates.json` — birthdays & dates (Round 57, dates.json
  version 1): "Ana 🎂", a birthday 24 Oct 1995, every year, note
  "Knjiga, čokolada", reminders 1 day before at 09:00 and 7 days before
  at 20:00; "Mama i tata", an anniversary on 29 Feb, no year, no
  reminders; "Ispit", an event 3 Nov 2026, once, note "Sala 4", a
  reminder on the day at 07:00.
- `v23/backup-plain.json` — backup (version 23) with them (no food).
- `v24/storage/dates.json` — dates that last (Round 59, dates.json
  version 2, `days`): "Ljetovanje 🏖", a holiday from 1 Aug, every year,
  **10 days**, note "Ponesi kremu", a reminder 7 days before at 18:00;
  "Sajam", an event from 30 Dec 2026, once, **4 days** (into 2027), note
  "Hala 1", no reminders; "Ana 🎂", a birthday 24 Oct 1995 (a day: no
  `days`), the standard reminder.
- `v24/backup-plain.json` — backup (version 24) with them.
- `v16/storage/notifications.json` — the notifications' history (Round
  31, notifications.json version 1; this phone only, not in backups):
  Iron 🩸 (medicine) on 12 Oct 18:00 UTC, "Zubar, čet" (planner, to 13
  Oct 11:00, `planner|2026-10-13|660`) on 13 Oct 08:50 UTC; cleared 12 Oct 19:00 UTC.
