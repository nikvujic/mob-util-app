# Pip's adventures — spec (Round 63)

Not built yet. From Nikola's notes (ROADMAP, Rounds 41 and 63).
**Decided** marks what Nikola has said; the rest are suggestions,
with the open questions in section 10.

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
  - two item boxes: **weapon** (the sword) and **off-hand** (empty for
    now);
  - suggested: an XP bar to the next level, "Adventuring now" or "Next
    adventure 12:00".
  A second tap (or the button, now "Info") goes back to his info card.
- **Not registered**: the card shows a **Register as adventurer** button
  instead. Outside **13:00–15:00** a tap says "Come back between 13:00
  and 15:00" (see question 1 for the window with the longer day).
- **Registering**: an animation where he **holds his sword in the air**
  for a few seconds with an **8-bit fanfare** (decided). Registering
  fills his batteries (Round 41). His **first adventure starts at once**
  (decided).

## 3. The adventure view (decided)

- While he adventures, Pip Home's room and the menu's room show the
  **adventure view**: Pip **in the centre**, running, while the
  **ground moves** under him (and things on it scroll past). Bugs come
  in from the right; he swings and they pop. The sky is the usual one
  for the time of day (and later the backgrounds).
- The menu's name line shows his **level** instead of his age while he
  adventures.

## 4. Starting and ending

- **Start**: he walks to the centre, **draws his sword** and runs right;
  the ground starts moving. This is only seen if someone is looking:
  at registering, at 12:00 exactly, or when a battery wakes him (below).
  Otherwise he's already running when the page opens (decided).
- **End at 18:00**: he slows, stops, puts the sword away and goes back
  to idling; seen only if someone is looking (decided).
- **Charging at 12:00**: he stops charging and goes (decided).
- **Powered down at 12:00**: he doesn't go. A battery given **until
  17:00** (an hour before the end) wakes him and he starts adventuring
  (decided). After 17:00 a battery wakes him as usual and he idles.
- **Asleep**: can't happen in the window (his sleep is at night).
- **App closed**: the whole adventure is worked out from the clock when
  the app opens, as energy is now (core/pip_energy): XP for each
  minute he was out and powered on.

## 5. Levels and titles

**XP = one per minute adventuring** (a full day is 360 XP). The level
comes from his XP as days of adventuring (D = XP / 360):

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

The table counts days he actually adventured; missed days push it back
(question 2).

**Titles**: a new title every 10 levels, up to level 80 (decided).
Suggested names:

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

## 6. Energy

- Suggested: adventuring uses energy at the same rate as being awake,
  so batteries matter as now. If he runs out mid-adventure he powers
  down where he is and XP stops. A battery before 17:00 sends him back
  out.
- Batteries still fly to him while he runs (he catches them without
  stopping).

## 7. Sound

- The fanfare plays through the app's own player (the SoundPool already
  in MainActivity), as a short 8-bit clip bundled with the app.

## 8. Data and backup

- pip.json v3 gets `adventurer`: `registeredAt` and `xp` (with the time
  XP was last worked out to). Backup v26, with new frozen fixtures and
  their hashes in storage_compatibility_test.
- A partial restore and Clear data treat it as part of Pip.

## 9. Order of work

1. Data: the model, the level/title rules (core, with tests), pip.json
   v3, backup v26, fixtures.
2. Brain: the daily activity, start/end, charging and power rules, XP
   from the clock.
3. Sprites and painter: the running Pip, sword swing, moving ground,
   bugs, start/end/register animations.
4. Pip Home's Adventures button and card, the register flow, the
   fanfare, the menu line.
5. Docs, Introduction, What's new, release.
6. Later: Skiing; items for the off-hand box.

## 10. Questions for Nikola

1. **Register window**: with the day now 12:00–18:00, should
   registering move to **13:00–17:00** (an hour in from each end, as
   13:00–15:00 was for 12:00–16:00)? Or stay 13:00–15:00?
2. **Missed days**: the levels in section 5 assume he adventures every
   day. Should a day he was powered off just be lost, or should XP
   follow the calendar from registering, so a year always means about
   level 90?
3. **Energy**: does adventuring use more energy than idling, the same
   (suggested), or none?
4. **Titles**: are the names in section 5 fine? Should the card show
   the next title and when it comes ("Knight at Lv 40")?
5. **Level-up**: when he levels up while you're watching, a little
   "LEVEL UP" moment (a flash and a short jingle)? And a new title,
   anything more?
6. **Notifications**: none (suggested), or "Pip is back from his
   adventure" / a level-up notice?
7. **Fanfare**: should it follow the phone's silent mode, or always
   play (it's on the media volume)?
8. **Taps while adventuring**: do the usual taps (the three-tap wake,
   petting, the angry walk-off) do anything while he runs, or are they
   off until 18:00?
9. **Random events** (bugs as an event, flower, butterfly, ball,
   screens): off during the adventure (suggested), since the adventure
   has its own bugs?
10. **Hats**: keep his hat of the day while he adventures?
