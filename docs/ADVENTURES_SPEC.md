# Pip's adventures — spec (Round 63)

Not built yet; waiting on Nikola's go. From Nikola's notes (ROADMAP,
Rounds 41 and 63); his answers are in, and **Decided** marks them.

## 1. What it is

- Once Pip is **registered as an adventurer**, his day has two
  activities: **idling** (everything he does now) and **adventuring**,
  **12:00–18:00** every day (decided). It isn't a mode he's switched
  into; he goes out **on his own** (decided).
- On an adventure he **runs right and fights bugs**, gaining **XP**
  (decided). **Skiing** is a special adventure for days when a Skiing
  date is on: he puts on skis and goes **down** instead of right
  (decided; built **after** the normal adventure).
- XP comes from **time only** (decided). Levels give **titles**, for now
  (decided).

## 2. Pip Home: the Adventures button and card (decided)

- Pip Home always has an **Adventures** button. A tap turns the info
  card into his **adventure card**:
  - his **level** where his age was ("Lv 23");
  - his **title** (section 5);
  - three item boxes: **weapon** (the sword), **off-hand** (empty for
    now) and **hat** (empty for now; later a hat equipped from the
    inventory overrides his hat of the day) (decided);
  - an **XP bar** to the next level (decided); no "next adventure" line.
  A second tap (or the button, now "Info") goes back to his info card.
- **Not registered**: the card shows a **Register as adventurer** button
  instead. Outside **13:00–17:00** a tap says "Come back between 13:00
  and 17:00" (decided: an hour in from each end of the day).
- **Registering**: an animation where he **holds his sword in the air**
  for a few seconds with an **8-bit fanfare** (decided). Registering
  fills his batteries (Round 41). His **first adventure starts at once**
  (decided).

## 3. The adventure view (decided)

- While he adventures, Pip Home's room and the menu's room show the
  **adventure view**: Pip **in the centre**, running, while the
  **ground moves** under him (and things on it scroll past). Bugs come
  in from the right; he swings and they pop, with a short vibration.
  Now and then one **hits him**: he flies back a little and his
  **sword flies out of his hand**; he gets up, runs to pick it up and
  runs on (only an animation: no health, nothing lost), with a
  vibration. The sky is the usual one
  for the time of day (and later the backgrounds).
- The menu's name line shows his **level** instead of his age while he
  adventures.
- **Taps do nothing** while he adventures, and there are **no random
  events** (flower, butterfly, ball, bug fights, screens) (decided).
- He **keeps his hat of the day** (decided).

## 4. Starting and ending

- **Start**: he walks to the centre, **draws his sword** and runs right;
  the ground starts moving. This is only seen if someone is looking:
  at registering, at 12:00 exactly, or when a battery wakes him (below).
  Otherwise he's already running when the page opens (decided).
- **End at 18:00**: he slows, stops, puts the sword away and goes back
  to idling; seen only if someone is looking (decided).
- **Charging at 12:00**: he stops charging and goes (decided).
- **Powered down at 12:00**: he doesn't go, and gets no XP while he's
  off (decided). A battery given **until 17:00** (an hour before the
  end) wakes him and he starts adventuring (decided). After 17:00 a
  battery wakes him as usual and he idles.
- **Asleep**: can't happen in the window (his sleep is at night).
- **App closed**: the whole adventure is worked out from the clock when
  the app opens, as energy is now (core/pip_energy): XP for each
  minute he was out. He can't power down once out (section 6), so an
  adventure is always **start → 18:00** or **powered on → 18:00**.

## 4b. The break (Round 64, decided)

- Once per adventure, **half an hour off**, only for looks: XP goes on
  as if he were running.
- **When**: if the app is open (or opened) between **14:00 and 16:00**
  and he hasn't had today's break, it starts then, so it's seen. If
  nobody looks, it's at 15:00–15:30. An adventure started after 15:30
  (a late battery) has no break.
- **Normal adventure**: the ground slows and a **tavern** slides in (he
  stays centred; the background moves), he puts the sword away, walks
  to a table and sits; a **plate of food** pops out of the window onto
  the table and he eats. At the end he gets up, draws the sword and the
  ground moves again.
- **Skiing**: the same at a mountain hut, with a **hot chocolate**.
- Later: more break events.

## 5. Levels and titles

**XP = one per minute adventuring** (a full day is 360 XP). The level
comes from his XP as days of adventuring (D = XP / 360). The curve is only the target: he goes up **one level
at a time** as usual, each level costing a little more XP than the one
before (decided):

- Year 1 (D ≤ 365): level = 1 + 89 × (D / 365)^0.8. Early levels come
  fast, then slow down to about 70 a year by the end of the year.
- Years 2–3: 70 levels a year (160 at two years, 230 at three).
- From year 4: 50 levels a year (280 at four years, 330 at five...).
  No cap (decided).

| Adventuring days | Level |
|---|---|
| 2 | 2 |
| 7 | 4 |
| 30 | 13 |
| 90 | 30 |
| 180 | 51 |
| 365 | 90 |
| 730 | 160 |
| 1095 | 230 |
| 1460 | 280 |

The table counts days he actually adventured; a day he was powered off
gives no XP (decided).

**Level up** (decided): when it happens while someone is watching, a
short **LEVEL UP** flash over him and a vibration, **no sound**; a new title shows on the card.

**Titles**: a new title every 10 levels, up to level 80 (decided,
these names):

| Level | Title |
|---|---|
| 1 | Rookie |
| 10 | Bug Squasher |
| 20 | Squire |
| 30 | Debugger |
| 40 | Knight |
| 50 | Veteran |
| 60 | Champion |
| 70 | Hero |
| 80 | Legend |

## 6. Energy (decided)

- Adventuring uses energy at the **normal** rate.
- He **can't power down** during an adventure: if his energy would run
  out, he keeps going and powers down **after it ends** at 18:00 (or at
  once then, if he's out of energy).
- Batteries still fly to him while he runs (he catches them without
  stopping).
- No notifications for adventures (decided).

## 7. Sound (decided)

- The register **fanfare** is Pip's **only sound**; everything else
  (level up, bug hits, getting hit, falls) is vibration.
  They play through the app's own player (the SoundPool already in
  MainActivity) on the **media volume**, so they follow the phone's
  volume (muted → silent). A short 8-bit clip bundled with the app.

## 8. Skiing (decided; after the normal adventure)

- On days with a **Skiing** date in Dates, the background is **always
  snowy**, and his adventure is **skiing down a hill** instead of
  running right: he puts on skis at the start, slides down (the slope
  moving under him), and now and then **falls**: a ski comes off and
  slides away; he gets up, fetches it, puts it back on and carries on
  (with a vibration). XP the same as a normal adventure.

## 9. Data and backup

- pip.json v3 gets `adventurer`: `registeredAt` and `xp` (with the time
  XP was last worked out to). Backup v26, with new frozen fixtures and
  their hashes in storage_compatibility_test.
- A partial restore and Clear data treat it as part of Pip.

## 10. Order of work

1. Data: the model, the level/title rules (core, with tests), pip.json
   v3, backup v26, fixtures.
2. Brain: the daily activity, start/end, charging and power rules, XP
   from the clock.
3. Sprites and painter: the running Pip, sword swing, moving ground,
   bugs, start/end/register animations.
4. Pip Home's Adventures button and card, the register flow, the
   fanfare, the menu line.
5. Docs, Introduction, What's new, release.
6. Skiing (section 8).
7. Later: an inventory to fill the off-hand and hat boxes.
