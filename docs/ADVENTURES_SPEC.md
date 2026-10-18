# Pip's adventures — spec (Round 63)

Built in Rounds 63–64 (v1.25.0); skiing (section 8) and the inventory still to come. From Nikola's notes (ROADMAP,
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
- **When**: he's looked at between **14:00 and 16:00**, none had today,
  and (Round 66) it's a **fresh look**: he'd gone unseen at least **five
  minutes** before (or the app has just opened). Watched as he sets
  off or comes back on with a battery, no break then; looked in on
  later, it starts. Nobody looks in that way: no break that day.
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
- Round 65: a **tap gives him a battery** while he's out too (decided):
  it flies from where you tapped to him and he catches it without
  stopping (a light buzz), one at a time. Plugged in, out, he isn't at
  his station, so it isn't refused for that. Registering fills his
  **energy** (his battery icon), not the batteries you hold (decided).
- No notifications for adventures (decided).

## 7. Sound (decided)

- The register **fanfare** is Pip's **only sound**; everything else
  (level up, bug hits, getting hit, falls) is vibration.
  They play through the app's own player (the SoundPool already in
  MainActivity) on the **media volume**, so they follow the phone's
  volume (muted → silent). A short 8-bit clip bundled with the app.

## 8. Skiing (Round 65–66: the spec; waiting on Nikola's go)

Skiing is **a different look for his adventure**, not a separate thing:
the same days out (12:00–18:00), the same XP, break and rules; only
what's drawn changes. **Decided** marks Nikola's answers.

### 8.1 Ski days

- A **ski day**: any day a Dates holiday of kind **Skiing** is on
  (each day of one that lasts several days), outside its travel (8.6).
- **Snowing all day** on ski days, day and night (decided).
- Not registered: the snow and his gear (8.2) only; he never skis on
  his own (decided: skiing replaces his adventure, it isn't an event).

### 8.2 The snowy day

- **Ground**: snow instead of grass, white with pale blue-grey shading
  and a few specks.
- **Snowflakes** drifting down and a little sideways, all day; while
  he skis they also stream back past him.
- A few **snowy pine trees**; the sky as ever for the hour (a little
  greyer by day).
- **His ski gear** in his field (decided): skis and poles stuck in a
  snowbank on one side. On his day out he walks over and **picks them
  up** first (the skis on his feet, the poles in his hands), then goes;
  seen at 18:00, he puts them back.
- A **ski beanie** all ski day (decided); a birthday's party hat still
  wins.
- His usual day (walking, events, sleep) goes on in it.

### 8.3 The slope (to pick: `docs/pip_ski_slope_drafts.png`)

Three ways to draw going downhill, him always in the middle:

- **A, tilted slope**: the ground slopes down to the right; trees,
  flags and bumps slide up and to the left past him. Reads most like
  "down a hill".
- **B, raised snowfield** (Nikola's idea): the snow fills more of the
  room; he stays put and the trees and flags **rise past him**, so he
  seems to go down.
- **C, flat glide**: like running, the snow moving left.

Suggested: **A**. Either way: **slalom flags** (red and blue) and
**bumps**, both at random (decided): a bump sends him up in a little
hop (a light buzz on landing). **No bugs**; the sword stays away (the
weapon box still shows it).

### 8.4 Falling (decided)

- Every **40–90 seconds** at random: he tumbles forward in a puff of
  snow (a medium buzz), **one ski comes off** and slides on ahead; he
  gets up, walks to it, steps back in, and carries on.

### 8.5 The break

- As the tavern (a fresh look between 14:00 and 16:00, half an hour,
  once a day), but a **mountain hut**: snow on its roof, a lit window;
  he leans his skis on its wall, sits at the table outside, and a
  **mug of hot chocolate** (steam rising) pops out of the window; he
  sips it as the break goes. Then skis back on, and down.

### 8.6 The trip: a bus there and back (Round 66, decided)

- A Skiing holiday in Dates gets a **travel time**: the trip there and
  the trip back (questions 8.8).
- While travelling, Pip is **in a bus**, all the time: the bus in the
  middle of his room, him in a window, the **road** (dashes) and
  roadside things (poles, trees, hills) moving past. **Nothing else
  applies**: no events, no taps or batteries, no station, no energy
  used, **no hat**. He **sleeps** in his seat at night (eyes shut,
  little z's). If he's an adventurer he still **gains XP** for
  12:00–18:00 as on any day, but no adventure is shown.
- **Snow**: on the way there, the snowy look comes in once **80%** of
  the trip is done; on the way back it goes once **20%** is done.
- **Leaving** (seen, or in Animations): the bus drives in and stops,
  its door opens, Pip walks in, the door shuts, and it drives off (the
  road starts moving). **Arriving**: the bus slows and stops, Pip steps
  out, the bus drives off. Not seen: he's simply in the bus, or back.

### 8.7 Pip Home's Animations

- **Skiing**, **Falling on skis**, **Off on a trip** (the bus leaving)
  and **Back from a trip** (arriving), as previews.

### 8.8 Questions

1. **The slope**: A, B or C (the picture)?
2. **Travel time in Dates**: how should it be entered? Suggested: on a
   Skiing holiday, **Travel** with **hours each way** (e.g. 6) and
   **leaves at** for each trip: there on the first day (default 06:00)
   and back on the last day (default 16:00). Or would you rather give
   the departure and arrival times outright?
3. **Ski days during travel**: on the first and last days, he skis only
   in what's left of 12:00–18:00 outside the bus (arrived at 12:00, he
   skis 12:00–18:00; on the bus till 14:00, skis 14:00–18:00). Right?
4. **Energy on the trip**: kept as it was (not used, not gained), and
   batteries still pile up on the clock meanwhile?
5. **Gear when not registered**: still shown in the snowbank as part of
   the scene, or only for an adventurer?

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
