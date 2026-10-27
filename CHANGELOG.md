# Changelog

All notable changes to the app. Versions follow `MAJOR.MINOR.PATCH`
(see [docs/RELEASING.md](docs/RELEASING.md)); each version is a GitHub
Release with the installable APK.

## [Unreleased]

## [1.43.0] - 2026-10-27

### Added
- **People**, a new Hub page: the people you know as boxes on a board you
  pan and zoom, each with a pixel face for their age (baby to 80+) in blue
  or pink, their name and age; important people **highlighted**, the
  **deceased** greyed with their years.
  - Tap someone to centre on them and open their info below; **Edit** for
    their name, gender, birthday, date of death, note and **relations**.
  - **Relations** make family trees: parent / child, partner (or former,
    dashed), brother or sister, or other with a word ("Kum"). A couple
    gets one line down to their children.
  - Drag people around: a small drag moves only them, a long one brings
    their family. **Tidy** lays everyone out as family trees (asked
    first, undoable); **Find** searches by name.
  - A birthday set here is on the **Dates** page too, with a People mark:
    there its reminders and note can be changed, the rest only here; and
    **Birthday from Dates** takes over one already there.
  - Lockable, in Clear data, in backups (version 32) and in *Restore part
    of a backup*.

## [1.42.0] - 2026-10-27

### Added
- **Rain radar (optional), in Internet Access.** Forecasts can miss light
  rain (Open-Meteo once said cloudy while it rained in Belgrade). Add your
  own free Tomorrow.io key (a copy button copies where to sign up) and the
  rain or snow right now comes from it, checked every 15 minutes; when
  it's dry, Open-Meteo's sky stays. The key is checked once when pasted,
  shown only by its last 4 characters, stays on the phone (not in
  backups) and is sent only to Tomorrow.io. If it stops working, the
  weather is Open-Meteo's alone and the page says why. The weather line
  ends with "rain by radar" or "rain by Open-Meteo" while a key is set.

## [1.41.1] - 2026-10-27

### Changed
- **Recipes:** *Export for ChatGPT* is now **Export for agents** (any AI
  agent: ChatGPT, Claude, ...), and the Import / export button has a
  clearer icon (⇄).

## [1.41.0] - 2026-10-26

### Added
- **Recipes: import / export as text.** A new button on the Recipes page
  (beside Ingredients):
  - **Export for import** copies a recipe you pick, for someone to
    import into their app.
  - **Export for ChatGPT** copies a recipe you pick as an example, with
    the rules of its shape and your ingredient names by section: paste it
    into ChatGPT, ask for a new recipe like it, and copy its answer.
  - **Import (paste)** reads a copied recipe (words or a code block
    around it are fine) and, after showing which ingredients are new to
    your list and where they'll go, adds it as a new recipe on top; new
    ingredients go into their sections (a new section if needed).

## [1.40.6] - 2026-10-26

### Changed
- **Packing:** tapping an item while editing offers **Count** first,
  then Rename.

## [1.40.5] - 2026-10-26

### Fixed
- **Recipes:** going into edit and back no longer jumps to the top; the
  page stays where it was scrolled.

## [1.40.4] - 2026-10-21

### Changed
- **Pip buzzes the phone through his animations:** wherever something
  lands, hits or clicks while you watch: the battery dropping and its
  bounce, the old one pulled out and landing, the new one clicking in,
  his hop after; falling over when he runs out, the battery reaching him
  and his hop when he's back on; out of the ground, out of his egg,
  settling down to sleep, the hop on waking; taking the cable and
  plugging in, unplugging, each segment his station or drone gives him;
  each bite, each dance beat, the hop when a notification or his pill
  comes, a flower picked, the ball bouncing, the snowman finished and
  the snowball hitting the glass. Calm ones (a blink, a butterfly, a
  shooting star) stay quiet.

## [1.40.3] - 2026-10-21

### Changed
- **Pip changing his battery, livelier:** the new battery bounces as it
  lands and glints while it waits; he stands a little off it, so the
  two batteries never overlap; the old one (no red bit in it any more)
  is thrown over his head to his other side, lands with a clunk and a
  puff of dust, and fades there; the new one clicks in with a crackle of
  sparks; then a happy little shake and a hop with sparkles. In Pip
  Home's Animations (*Changing his battery*) it plays when he's full
  too, and gives no energy.

## [1.40.2] - 2026-10-21

### Changed
- **Packing, editing a list:**
  - Sections are **dragged** by the right of their name, as in
    Ingredients (a line shows where one goes); Move up / down are gone.
  - **Add section** is a button by Done, not at the end of the list.
  - **+ Add** under a section taps anywhere across its width.
  - Deleting a section says how many **items** go with it.

### Fixed
- **Packing:** an item dropped between two sections no longer settles
  there and snaps back: it stays where you let it go.

## [1.40.1] - 2026-10-21

### Changed
- **Packing lists, your way:**
  - **Each list has its own sections.** In edit mode, a section's name
    gives Rename, Move up, Move down and Delete (its things go with it,
    asked first; a list keeps at least one); **Add section** is at the
    end. Other is a section like any other.
  - **Default sections** (the button beside +) are what a new list
    starts with; changing them doesn't touch the lists there are.
  - **+ Add** sits under each section's things, not by its name.
  - A new list says **New list**, and Done takes you back to the lists,
    where it shows (not into it).
  - **Back** while editing asks **Save or Discard** if anything changed
    (Discard puts the list back, or drops a new one).
  - Things are deleted by **holding** them to select (no Undo or Redo
    needed); a tap renames one or sets its count.
  - In view mode, rows are a **normal size**; every section shows, empty
    ones too; **Reset** asks first, with no Undo toast.
  - Copy list goes back to the lists, with the copy.

### Fixed
- Typing a packing list's name no longer makes the page bounce.

## [1.40.0] - 2026-10-21

### Added
- **Packing lists**, a new Hub page: lists like "Ski trip" or "Beach",
  each showing how much is packed. A list opens with its things under
  their sections (Documents, Clothes, Toiletries, Electronics, Medicine,
  Other, and your own), each with a big box: tap anywhere on a row to
  tick it; ticked things stay in place, struck through. **Reset**
  unticks them all (with Undo). **Edit**: the name, a section's **+**
  adds things (no two of a name in a section), a tap renames one, sets
  how many or deletes it, and its handle drags it, into another section
  too. **Copy list** asks the new name and which sections come along.
  The sections are shared by every list (the button beside +): add,
  rename, reorder, delete (its things move to Other). Locks, Clear data,
  backups and restoring part of a backup include it.

### Changed
- **Spotify**: the page no longer says it may not start when Spotify
  was closed: it does.

## [1.39.0] - 2026-10-20

### Added
- **Spotify in the morning**, a new Hub page: turn it on, pick a time,
  the days and a volume. At that time the phone sets its music volume
  and presses play, so Spotify carries on with what it last played. It
  works with the app closed and after a restart. (If Spotify was closed
  completely, it may not start.)

## [1.38.2] - 2026-10-20

### Fixed
- **Important medicine, hold to take**: while you hold, and once it's
  full, the dialog can't be closed (Cancel greys out, a tap outside and
  Back do nothing), and a full one always counts as taken (one was lost).
- **Ingredients: no duplicates.** Adding or renaming to a name that's
  there already (capitals and spaces aside) says where it is ("Milk is
  already in Dairy") and keeps the box open to fix it.
- **Ingredients' sections** are dragged only from the right edge of
  their name (where an ingredient's handle is); a line shows where the
  section will go (only between sections), and it drops there without
  dipping and snapping back. Dragging near the top or bottom scrolls.
- **Text selection handles** grab from below the text in every field
  (as in notes since 1.33.0), not just notes and recipes.

## [1.38.1] - 2026-10-20

### Added
- **Save or Discard on Subscriptions, Dates and meals**, as on a note:
  changed, Back asks; **Discard** puts it back as it was (a new one is
  deleted), **Save** keeps it, a tap outside stays. As before, what you
  type is kept as you go (Back again, closing the app).

### Changed
- **Pip charges faster still**: a segment every 8 seconds at his
  station while watched (it was 15).

### Fixed
- **Calendars open on the day set**, and on today when none is: 1.37.4
  opened them all on today's month. A new subscription's day (a month on
  until you pick one) opens on today. The card expiry's months open on
  its year.

## [1.38.0] - 2026-10-20

### Added
- **Subscriptions: move cards around.** Hold a card and drag it to
  where you want it, as on the Hub. The cards stay in your order (a new
  one goes last) instead of being sorted by state.

## [1.37.5] - 2026-10-20

### Changed
- **Pip charges twice as fast** at his station while you watch: a
  segment every 15 seconds (it was 30).

### Fixed
- **A tap outside a field lets it go** (the keyboard closes), on every
  page, sheet and dialog: the Subscription page's fields and others used
  to stay focused.

## [1.37.4] - 2026-10-20

### Fixed
- **Calendars always open on today's month** (picking a subscription's
  day, a date's, a medicine's, a meal's, a routine's last day, moving a
  block): they used to open where the thing's own day was, which looked
  like where you'd last been. The day already set shows picked when it's
  in this month. The card expiry's month picker opens on this year.

## [1.37.3] - 2026-10-20

### Fixed
- **The month picker** (a card's expiry): the months were squished
  together; now three to a row, four rows, roomy buttons with space
  between them.

## [1.37.2] - 2026-10-20

### Changed
- **Subscriptions: a card's expiry is a month and year** ("expires
  10/26", as on the card), picked from a year's twelve months; it's good
  through the month's last day. One set with a day before keeps its
  month.

### Fixed
- **Subscriptions' cards**: the card, warning and reminder icons line up
  with their text.

## [1.37.1] - 2026-10-20

### Changed
- **Subscriptions**: a card's expiry shows in **orange** when it's a
  week or less away and in **red** once it has gone by.

## [1.37.0] - 2026-10-20

### Added
- **Planner: move a block to another day.** Tap a block: **Move to
  another day** picks the day (tomorrow first, handy for a missed one).
  It keeps its time if that's free there; if not, it says so and to what
  time it'll move (the nearest free time as long), Move or Cancel. Undo
  moves it back.

### Changed
- **Planner: new blocks and routines remind at their start** by default
  (it was Off); pick Off in the sheet for none.
- **To-do: a completed thing tapped goes back where it was** (waiting
  again if it was), not to the end, unless the list changed meanwhile.
- **Pip at the tavern** sits on his bench, his feet over its front (he
  stood on it), centred on it.

## [1.36.3] - 2026-10-20

### Changed
- **Notifications show names unless set to Private.** A locked page
  (the Planner, the Hub, or one of its pages) used to hide its
  notifications' names too ("A block is on"); now only the Private
  setting on the Notifications page does.

## [1.36.2] - 2026-10-19

### Fixed
- **Picking a date or a time** while typing in a field (a subscription's
  name, a date's title, the planner's, Medicine's, Food's): the field
  lets go, so the keyboard no longer comes back once the picker closes.

### Changed
- **Chips** (Subscriptions' state and reminders, Dates' types, the
  planner's days and more): the one picked has no tick any more (it was
  hard to see, worst on a coloured dot); it's filled with a wash of the
  theme's colour and edged in it, clear in every theme.

## [1.36.1] - 2026-10-19

### Added
- **Subscriptions**: the **card's expiry date** (a virtual card runs
  out), set on a subscription's page and shown on its card ("Virtual
  0912 · expires 10 Nov"). If the card expires before the subscription
  next renews, the card says so in red.

### Changed
- **Subscriptions' cards** look like normal cards now: rounded, lightly
  tinted with a thin outline in their state's colour, and the state as a
  small pill. The thick edge on the left is gone.
- **Pip's trees** stand still with the weather off (they swayed lightly).

## [1.36.0] - 2026-10-19

### Added
- **Subscriptions**, a new Hub page: what you pay for, as cards two to a
  row coloured by their state: **active** (green), **to cancel** (orange:
  it still renews, but you mean to cancel it before then), **cancelled**
  (blue: still on until a day) and **inactive** (grey: lapsed, the card
  ran out, a payment failed). Each card shows the price (a ~ when it's
  about that), its day (*Renews 3 Nov*, *Cancel by 17 Nov*, *Active
  until 13 Nov*), the card it's paid with (or *Card unknown*), its
  reminder and a note. At the top: what they come to a month. A
  notification on its day at 09:00, and before it if you set one (2 days
  before for one to cancel); a red dot on the tile when one's to be
  cancelled soon. In backups, Clear data, and with a lock of its own.

### Changed
- **Pip's trees** sway only in the wind: still when it's calm, a light
  sway in a breeze, hard when it's windy (or stormy). The wind comes
  with the weather (Internet Access shows it too); with the weather off
  they sway lightly as before.

### Fixed
- **Pip, angry** after being thrown in: his fist stays beside his head
  now, shaken up and down. It floated above his head, too far out.

## [1.35.0] - 2026-10-19

### Added
- **Waking Pip at night**: tap him **three times** while he's asleep and
  he wakes for **15 minutes**, so you can give him a battery or let him
  charge. One eye opens first and looks about, then he gets up the usual
  way. He looks very tired the whole time and walks slowly, then falls
  asleep again. Once a night.
- **Waking him early**: from **07:00**, three taps wake him for the day,
  instead of waiting till 08:00.
- Pip Home's status says *TAP HIM 3 TIMES TO WAKE HIM* when he can be
  woken, and the Animations list has *Woken at night*.

### Changed
- **Planner routines** are just there now: there's no box to tick them
  off (and no Done on their notification), and they don't show on past
  days.
- **Ticked-off blocks on past days are deleted** by themselves, when the
  app opens or comes back. Tick one off on a past day and it's cleared
  at once (with Undo).

## [1.34.1] - 2026-10-19

### Fixed
- **Pip's adventure**: when a bug knocked him over, the trees kept going
  by while he lay there and fetched his sword. They now stand still with
  the ground, and catch up a little as he runs on (so the menu's Pip and
  Pip Home's still agree).
- His **sword**, knocked flying, now turns over in an arc and lands flat
  on the ground. It used to come down point first, through the ground,
  and then lie partly in it.

## [1.34.0] - 2026-10-19

### Added
- **Pip and the weather** (with the weather on in Internet Access, or
  tried on in Pip Home):
  - **Thunderstorm**: his **tent** goes up round him and he waits it out
    inside. He can't move and nothing else happens, though now and then
    his eyes peek out and the tent shakes with the thunder. A battery you
    give him flies into the tent. Asleep or off, the tent goes up over
    him; busy with something, he finishes it first. When the storm's
    over, the tent comes down.
  - **Rain**: he opens his **umbrella**, jumps in **puddles** (a
    splash), and now and then **twirls** under the umbrella.
  - **Drizzle**: no umbrella; now and then he holds a hand out to feel
    it.
  - **Snow**: he **builds a snowman** (it stays while the snow lasts,
    then melts), catches **flakes** on his tongue, and throws a
    **snowball at you**; it splats on the glass.
  - **Fog**: he walks slowly, and now and then he's **lost** (a question
    mark, looking this way and that).
  - When the weather changes, he stops and looks up, and the rain or
    snow comes in over a few seconds.
  - On his **adventure**: in a storm he stops and waits it out in his
    tent by the path; in the snow, **snowmen** come at him among the
    bugs (two strikes); in fog he runs slower and foes loom out of it;
    in the rain, splashes at his feet.
  - Pip Home's **Animations** has them all (each tries its weather on),
    and his tent, his umbrella and the fog.

### Changed
- **Trees**: both usually the same kind (two kinds now and then), and
  the evergreen **pine** is rare (about 1 in 20), except in **winter**,
  when it's more likely than not.

## [1.33.0] - 2026-10-19

### Added
- **Pip's trees** come in three looks: the oak, a **birch** (white bark,
  a tall crown, bare twigs hanging in winter) and a **pine** (green all
  year, snowy when it snows). Each spot gets one at random each time the
  app opens.

### Changed
- **Pip's break**: he sits still on a proper **bench** (he used to bob
  up and down, like squats) and eats bite by bite: his hand brings each
  bite from the plate to his mouth, and he chews. The plate empties
  after a few bites. At the mountain hut he lifts his **hot chocolate**
  to his mouth for each sip. The **tavern** is redrawn: a shingled roof,
  timber-framed walls on a stone base, an arched door with a hanging sign
  and a lantern, and a flower box under the window. The table is new
  too.
- **Selection handles** (notes and everywhere text is edited): a
  handle's touch area now reaches outwards, away from the text (right of
  the end's handle, left of the start's). Only a sliver of it is over
  the text, so tapping beside a handle no longer grabs it.

### Fixed
- During his break, the menu's Pip and Pip Home's showed his field's
  trees in different places. Both now follow his time out.
- A tree on the left of his field could be drawn mostly off the edge.

## [1.32.0] - 2026-10-19

### Added
- **Pip's adventures, watched**: his XP now goes up as he strikes bugs
  down. Each one collects what he's earned since the last, and the XP
  rises over it ("+2 XP"). He still earns it by the time he's out, so
  days you don't look in count just the same. XP is now ten a minute
  (3600 a full day; levels are as before, just ten times the numbers).
- **Bigger foes**: now and then a blue **beetle** (two strikes) or a
  purple **spider** (three) instead of a bug. They stagger back and
  flash when struck, with dots over them for the strikes left.
- **A boss**, once a day out, if you're lucky enough to be watching:
  a giant bug in a crown, six strikes, worth **50 XP**. Pip Home's
  Adventures has a **Boss** preview to see it.
- **Pip Home's adventure view**: while he's out, Pip Home opens on his
  adventure card (level, XP, items) by itself. *Info* on it switches
  to his info card and settings (animations and the rest), *Adventures*
  back; the adventure view has no settings card.

### Fixed
- A bug that knocked Pip over could stay on the screen after he got up
  and ran on, so no other bug came.

## [1.31.0] - 2026-10-19

### Changed
- **Pip's skiing**: he now skis **down** the slope, swaying gently side
  to side, seen from behind: trees and flags come up from below him and
  shrink away to the mountains on the horizon. After a fall he clicks
  his ski back on where he is, with no walking about.
- **Pip's bus** is much bigger: he sits behind a window with glass,
  seats and room around him, not his face filling it. The roadside
  trees stand beside the road, not on it.
- **Trees** in his field are a lot bigger and more detailed, and stand
  in new places each time the app opens.
- **Rain** falls slanted, in two layers, with splashes on the ground.
- A new **ski beanie**: striped, with a cuff and a pompom, pulled down
  over his head.
- **Christmas** is no longer 20 December to 7 January: **New Year's
  Eve** (all of the 31st, into the small hours) keeps the pine with
  lights, fireworks after dark; **Christmas** is now the Orthodox one,
  **7 January**, with its own look: a badnjak (an oak branch tied with
  a red ribbon) in straw, and a lit candle.

### Fixed
- In the **Adventure** preview, the bugs seemed to teleport in front of
  him; they now crawl in from the edge like any other.

## [1.30.0] - 2026-10-19

### Added
- **Planner: a notification while a block is on.** From a block's (or
  routine's) start, a quiet notification stays in the tray, counting
  down to its end; its **Done** ticks it off. It goes when the block
  ends, is ticked or changes. On by default; Notifications → Planner →
  *While a block is on* turns it off.
- **Dates**: what's on **today** is at the top, above Upcoming, and
  one-off dates gone by are kept under **Past**, at the end. A card's
  reminders are on their own line, with a bell.

## [1.29.1] - 2026-10-19

### Fixed
- **Shop's search** is a button beside **+** at the bottom, not in the
  top bar (buttons belong at the bottom, under your thumb), and it
  searches the **bought items** only: the list to buy stays as it is.
  Its magnifier and text now sit on one line.
- **Notes**: after **Select all** in a long note, the Cut / Copy / Paste
  menu was left out of sight at the note's start; it now shows where you
  can tap it.

## [1.29.0] - 2026-10-19

### Added
- **Internet Access** in the menu (second to last). The app uses no
  internet unless a service is turned on there; the first is the
  **Weather**, from Open-Meteo (free, no account): search your town or
  city, pick it from the matches, add more to switch between them. It's
  fetched every hour or so while the app is open, for Pip's sky; the
  page shows the weather now and fetches it again on a tap.
- **Pip's field through the year.** A tree in its season's colours
  (blossom and drifting petals in spring, green in summer, orange with
  leaves falling in autumn, bare in winter), swaying in the wind; the
  grass changes too, and clouds drift by. It dresses up for
  **Halloween** (lanterns lit after dark, bats), **Christmas** (a pine
  with blinking lights, 20 December to 7 January), **New Year's Eve**
  (fireworks) and **Easter** (painted eggs).
- **The weather in his sky**, with Internet Access's weather on: grey
  clouds over the sun and stars, rain or drizzle, snow falling (and on
  the ground), fog, and storms with lightning. No flowers or
  butterflies in rain, snow or winter; no shooting stars under clouds.
- Pip's page: under **Background**, try a **season**, the **weather**,
  one of his **days** or a **time of day** on his field (with a
  background and a hat; gone when you swipe back).

## [1.28.1] - 2026-10-19

### Fixed
- **Notes** (and everywhere text is edited): since v1.27.0, tapping in
  the text showed the cursor's handle far off to the right of the
  cursor, every time.
- **What's new** always shows the whole version with its patches (1.28.1
  shows 1.28.1 and 1.28.0), even after reading an earlier patch's, and
  is then headed with the version, not "since" the one read.

## [1.28.0] - 2026-10-19

### Added
- **Shop: search.** The magnifier opens a search field above the
  keyboard; typing shows only the items with it in their name (any
  case), in both lists, and the list still scrolls. Closing the keyboard
  keeps the field (for a better view); its **×** closes it, as does Back.
  Nothing matching: **Add “…”** adds what you typed.
- **Shop: A–Z.** A button on the **Items** header shows the bought list
  in alphabetical order (no drag handles then); again for its own order.
  It's only how it's shown: items still go on top of its own order, and
  the choice is remembered.
- **Typed amounts** ("1-2", "a bunch"). Shop's amount sheet has a
  **Text** choice to type the amount; the button by the item takes it
  back to none. A recipe's quantity sheet has **Text** too, and an
  ingredient's typed quantity (or spoons, "300 ml") now goes to Shop as
  its typed amount, instead of no amount.
- **Planner: all reminders.** The bell button now lists every reminder,
  the next first, with its day and time (those gone by, not ticked off,
  last). Tick several and **Delete** them at once (with Undo), or **Add
  reminder** from there. With none yet, it goes straight to adding one.

## [1.27.0] - 2026-10-19

### Changed
- Pip's **break**: the five minutes away count only when you **saw him
  set off** (registering, or back on with a battery); otherwise it
  starts the first time you look in between 14:00 and 16:00, even if
  you've been watching. Opening the app as it starts, you see him run
  up to the tavern (or hut) and sit down.

### Fixed
- **Recipes**: typing a recipe's name made the page bounce at every key.
- **Selection handles** (notes, recipes): a handle's touch area reached
  up into the line it marks, so a tap on the text there grabbed it; it
  now starts at the handle and reaches down.
- **Pip**: opening the app unplugged, after it was plugged in last time,
  his charging station flashed up and sank again; it now waits for the
  phone to say.

## [1.26.0] - 2026-10-18

### Added
- **Pip's ski trips.** A Skiing holiday in Dates makes his days there
  **snowy**: snow on the ground, flakes falling all day, snowy pines, a
  **ski beanie** (a birthday's party hat still wins) and his **skis and
  poles** in a snowbank.
- On a ski day his adventure is **skiing**: he picks up his gear and
  goes down a **raised snowfield**, trees, slalom flags and bumps rising
  past him (a hop over each bump); every 40–90 seconds he **falls**, a
  ski slides off, and he fetches it. His break is at a **mountain hut**
  with a **hot chocolate**. At 18:00 he puts his gear back.
- **Travel** for a Skiing holiday: hours each way, leaving at 06:00 on
  its first day and coming back at 11:00 the day after its last
  (changeable). On the way Pip rides a **bus**: the road moving, him in
  a window, asleep at night, nothing else going on (no energy used,
  batteries still pile up). Seen, the bus pulls in and he gets on, or
  it stops and he gets off. The snow comes 80% of the way there and goes
  20% of the way back. A day the bus is on the road between 12:00 and
  18:00 he doesn't ski, but still gains the day's XP.
- Pip Home: **Adventures** previews (an adventure, skiing, a bus trip),
  played in his field; no XP; they stop when you go back to his card.

### Fixed
- Pip's adventures: a day you didn't open the app gave no XP; now it
  counts if he had energy at 12:00.
- Pip Home's adventure card: "Not an adventurer yet" and "Come back
  between 13:00 and 17:00" ran off the card's edge on a narrow phone;
  they wrap now.

### Changed
- **Pip's adventures**: a **tap gives him a battery** while he's out
  too: it flies to him and he catches it as he runs. Plugged in, he
  isn't refused one for charging while he's out.
- His **break** starts only when you look in after **five minutes or
  more away** (between 14:00 and 16:00), never while you're watching:
  so not as he sets off in front of you or comes back on with a
  battery.

## [1.25.0] - 2026-10-18

### Added
- **Pip's adventures.** Pip Home's card has an **Adventures** button:
  his adventure card. Between **13:00 and 17:00** he can **register as
  an adventurer**: he holds his sword up high to an 8-bit **fanfare**
  (his only sound, on the media volume) and goes out at once.
- From then on he goes out **every day from 12:00 to 18:00** by
  himself: in the middle of his field, **running** while the ground
  moves under him, striking the **bugs** that come at him (a buzz for
  each). Now and then one **gets him**: he's knocked back, his **sword
  flies off**, and he goes back for it.
- Between **14:00 and 16:00**, the first time you look, he takes a
  half-hour **break**: a **tavern** comes up, he sits at its table and a
  plate of food flies out of the window to him; he eats it as the break
  goes. Only for the look: he keeps gaining.
- **XP**: one a minute out (360 a full day), and **levels**, one at a
  time, each a little longer than the last: about level 90 after a year
  out, 160 after two, 230 after three, 280 after four, then 50 a year,
  no cap. A **title** every 10 levels up to 80 (Rookie, Bug Squasher,
  Squire, Debugger, Knight, Veteran, Champion, Hero, Legend). A level up
  you see: **LEVEL UP** over him and a buzz.
- His **adventure card**: his level and title, an **XP bar**, and boxes
  for his **weapon** (the sword), **off-hand** and **hat** (empty for
  now). In the menu, while he's out, his **level** shows instead of his
  age.
- Out, he **can't run out**: if his energy is gone, he powers down
  after 18:00. Off at 12:00, he stays home, but a battery before 17:00
  sends him out. Charging at 12:00, he unplugs and goes. Taps and his
  usual events wait till he's back.

## [1.24.0] - 2026-10-16

### Added
- **Pip's hats by the day**: now and then (about 6–7 days a month) he
  wears a random hat all day (a crown, a top hat, a wizard hat, a cap, a
  beanie), and some days have their own: a **Santa hat** from 25
  December to 2 January, a **witch hat** on 31 October, **bunny ears**
  at Easter (Orthodox; Sunday and Monday), a **heart band** on 14
  February. A birthday's party hat comes first. The new hats are on Pip
  Home's Hats list too.

## [1.23.0] - 2026-10-16

### Added
- **Dates: kinds.** A holiday can be **Skiing**, **Beach** or a **Trip**;
  an event can be a **Wedding** (its card shows the kind's icon). Pip's
  ski trips come later.
- A **wedding** reminds **a week and a month before** (if its reminders
  weren't changed by hand).

### Changed
- **Dates: each type its own form.** A birthday and an anniversary are
  every year (no switch); *Year known* says what it's for ("for the
  age", "for which anniversary"). A holiday and an event are on a date
  with its year, once (no *Every year* or *Year known*), and can last
  several days. *Other* still chooses. The note has a hint per type.
- **Dates cards say it all**: the day (no year for one every year; it
  showed the next one's year, which read as a birth year), how soon,
  the age or which anniversary, and a second line with its kind, how many
  days, *born 1995* / *since 2016*, and its reminders ("1 day, 1 week
  before").

## [1.22.0] - 2026-10-16

### Fixed
- **Dates reminders never came**: they had no notification channel, so
  scheduling stopped at the first one (and reminders after it, of any
  page, were lost too).
- **Notifications vanished from the tray** when the app opened: they now
  stay until you open their page (Planner, Medicine, Dates, Backup) or
  swipe them away.
- **Notes**: dragging a selection's handle past the top (or bottom) of a
  long note raced a screen at a time and jumped about; now, held there,
  the note scrolls on steadily (faster the further out) and the
  selection follows, up to the first line.
- **Pip** flashed a smile at each blink when tired: a blink now keeps his
  mouth.
- The **moon**'s dark ring at night is gone.

### Changed
- **Pip hatches** with two segments and a battery to give him (was:
  full, none).
- **Dates**: a new date reminds **a day and a week before** (09:00).
- A **locked Hub page** or the **to-do note** asks for the fingerprint
  (or password) as soon as you open it.
- **What's new** (here, in the Introduction) lists every version since
  the one you last read about, not just the latest.
- The Introduction is brought up to date.

## [1.21.0] - 2026-10-15

### Changed
- **Dates**: a day with dates is shown as a circle in their colours (as
  Food shows rated days) instead of dots under it: one kind filled,
  several kinds split in slices, two or more of one kind with a border.

## [1.20.0] - 2026-10-15

### Added
- **Dates**: a holiday or an event can **last several days** (Lasts,
  − / +, up to 31): it shows on each of them in the calendar, its card
  says its days ("Sat, 1 Aug – Mon, 10 Aug") and "on now" while it's on;
  reminders come before its first day.

### Changed
- Pip's **sky follows the seasons**: dawn, day, dusk and night by the
  sun's real times for the date (an October evening is dusk soon after
  six, a June one after nine), not fixed hours.
- Pip **stops charging when he's full**: he unplugs and goes about, and
  goes back once he's used a segment.
- **Food**: Delete meal asks first.
- **Dates**: the **+** button is always on the right.

## [1.19.0] - 2026-10-15

### Added
- Pip's **charging station charges him**: while you watch him (the menu
  or Pip Home) at the station with the phone charging, a segment every
  30 seconds. **Off** with the phone plugged in, the station sends out
  a **drone** that beams a segment into him; then he's up and walks
  over to plug in.
- **Shop**: with one item selected, **Rename** (between Select all and
  Delete); typing in the add field offers your **bought items** that
  match, a tap puts one back on the list.

### Changed
- Pip uses **energy twice as fast** (a segment every 4 hours awake),
  a little less than the batteries bring if each is given as it comes.
- Pip's **hats** sit in the middle of his head (over his antenna); the
  **party hat** is bigger, striped, with a pompom.
- **Shop**: adding an item that's there already moves it to the list
  instead of adding a copy.
- **Food**: putting the keyboard away closes the index; Back first
  closes it, a second Back leaves.
- **Dates**: Delete asks first.
- **Settings**: Introduction after updates comes before the To-do note.

### Fixed
- Pip's battery could look **full for days** while the phone was
  charging (it kept what he had when plugged in); it now shows what he
  has.
- Opened while off with the phone plugged in, Pip was shown charging.

## [1.18.0] - 2026-10-15

### Added
- **Dates**, a new Hub page: birthdays, anniversaries, holidays and
  events on a month calendar, with what's coming ("in 9 days",
  "turns 31"). Each has a title, a kind, its day (the year if known),
  every year or once, a note, and up to 3 reminders (days before and
  a time; a new one reminds the day before at 09:00). A green dot on
  the tile on someone's birthday, until you open it. Notifications
  with the usual settings; lockable, in backups (and restoring part of
  one), in Clear data.
- **Pip's hats**: a party hat on someone's birthday and on his own
  (beside him while he sleeps), and on Pip Home's settings card a list
  of hats to try on him (party hat, crown, top hat, wizard hat, cap,
  beanie).

### Changed
- Pip **wakes up** more slowly, with a big yawn as he stretches.
- Pip Home's **animations, background and hats** are previews that go
  together, gone when you swipe back to his card or leave.

### Fixed
- Pictures on Pip's screen (the charging bolt, the battery…) were
  mirrored when he faced left.

## [1.17.2] - 2026-10-15

### Fixed
- **Food**: scrolled to the index's end, a drag on it scrolls the page
  (a flick flings it on) instead of stretching the index.

## [1.17.1] - 2026-10-15

### Changed
- **Pip's medicine reminder stays** while the red dot is on: whenever
  he's up and about it's the first thing he does (before going to
  charge or picking up a battery), the pill on his screen with a hop now
  and then, until the dose is marked. Not while he's asleep.

### Removed
- The **notifications button** in the Medicine page's top corner (its
  settings are on the Notifications page, in the menu).

## [1.17.0] - 2026-10-15

### Changed
- **Pip changes his battery by hand**: he walks up beside it, a hand
  pulls his old battery out of his side and throws it away, then picks
  up the new one and pushes it in. It's in Pip Home's Animations too, as
  a preview (none of your batteries used).
- His **hands** are closer to him (charging, the sword and the others),
  and only the one he uses shows.
- **Food**: with the keyboard down, picking a recipe from the index no
  longer brings it back up (a tap on the field does); scrolled to the
  index's end, a drag goes on to scroll the page.

### Removed
- The meal page's **Same as** section.

## [1.16.0] - 2026-10-15

### Added
- **Pip reminds you of your medicine**: while a dose is due (the red
  dot on Medicine), he shows a pill on his screen with two hops, soon
  after you see him and then every so often until it's marked.
- **Pip eats**: after a recipe has been open 5 minutes or more, the next
  time you see him within the hour he has a meal: a plate in his hands,
  three bites (crumbs falling), then a happy face. Once for each recipe
  read. Both are in Pip Home's Animations.

## [1.15.1] - 2026-10-15

### Changed
- **Food**: the index under the food field has an **X** to close it,
  and stays a set height, scrolling inside when it's longer.
- **Pip** wakes up more slowly (eyes shut a moment, a stretch, then the
  hop); his **sword** is new (a shining blade, a gold guard with a red
  gem) and held out away from him; **bugs** are bigger, with feelers and
  stripes; the **#!** when he's angry sits lower, just over his head; a
  picked **flower**'s stem is in his hand; picking something up, he
  crouches with his feet on the ground.
- The phone gives a little **buzz** when he kicks the ball, strikes a
  bug, or lands from the sky or a throw.

### Removed
- The pictures on Pip's screen just for fun (the ?, HI, star eyes and
  their flashing red, the heart, loading, the wink). Notifications
  still show there.

### Fixed
- Facing left, what's on his screen was mirrored.

## [1.15.0] - 2026-10-15

### Added
- **Pip's entrances**: besides coming out of the ground, he **drops in
  from the sky**, or, in the menu, is **thrown in from the side** by its
  swing, and is **angry** about it for a moment (a scowl, a shaken fist,
  cross words). One at random the first time, and again when you're back
  after a while.
- **Things happen in his field** now and then: **bugs** he fights off
  with a **sword**, a **flower** he picks and holds, a **butterfly** he
  watches, a **ball** he kicks away, a **little dance**, pictures on his
  **screen** (a heart, music, star eyes, HI…), and at dusk or night a
  **shooting star**. When a **notification** comes, his screen shows one.
  All of them are in Pip Home's Animations.

### Changed
- **Richer skies**: more colours from top to bottom (dusk goes from
  indigo through purple and pink to orange and gold), smoother bands,
  clouds with light and shade (warm at dawn and dusk), a sun with a glow
  (low and orange at dawn), a moon with a halo and craters, and stars in
  a few colours.

## [1.14.4] - 2026-10-15

### Changed
- Food: the calendar's days are small circles again (the month stays).
- Food, a food's page: the bars have a proper legend (a coloured mini
  bar for meals with it, a grey one for without, and what the counts
  are), and **bad or awful** is shown as two bars, with it and without,
  with their percentages.

## [1.14.3] - 2026-10-15

### Added
- Food: renaming a food to another food's name **merges** them (asked
  first, with Undo): its meals become the other's and their tags are
  joined, so "Egg" and "Eggs" count as one.
- Food: a meal's **day** can be changed, not only its time.

### Changed
- Food: the Foods list says what tags are for while some foods have
  none; Statistics says how many meals aren't rated yet (they don't
  count).

## [1.14.2] - 2026-10-15

### Changed
- Food statistics: each verdict sits centred beside its food; a food
  without one says what it still needs (more rated meals with it, or
  without it).

### Fixed
- Food: a food deleted and later added again by the same name gets its
  meals back, instead of showing twice in the statistics.

## [1.14.1] - 2026-10-15

### Added
- Food statistics **by symptom**: for each symptom you've logged, the
  foods it follows clearly more often than without them (the same fair
  comparison as the verdicts; symptoms don't change the verdicts, which
  come from the faces).
- Food: the index of foods has a **Recipes** section: a tap on a recipe
  opens its ingredients, all ticked, to choose which to add.

### Changed
- The Hub's tiles in a new default order: Counters, Medicine, Placard,
  Pip, Recipes, Food (tiles you've arranged stay as they are).
- The Introduction's *What's new* after a patch shows its whole version
  (here 1.14.0 and 1.14.1).

## [1.14.0] - 2026-10-14

### Added
- Food statistics in depth: a tap on a food (or kind) opens its page:
  the verdict and why, how its meals were rated against meals without
  it (a bar per face), the symptoms after it, what it was eaten with,
  and every meal with it, dated (a tap opens one).

### Changed
- Food: a **month calendar** like Medicine's history instead of a week's
  line, each day a circle in its worst meal's colour.
- Food: foods are added from an **index** under the field, in sections
  (*Foods* used before, the recipes' *Ingredients*), narrowed as you
  type; no separate From ingredients button. A food added twice flashes
  its chip.
- A meal's faces go from bad to good; **Delete meal** is a button at the
  end of the page.

## [1.13.0] - 2026-10-14

### Added
- **Food** in the Hub, a food tracker: log meals (the kind guessed from
  the time; foods typed, suggested most eaten first, picked from the
  ingredients list, or the same as a recent meal), rate how each went
  (five faces, symptoms, a note), see the week coloured by each day's
  worst meal, keep a list of foods with tags (dairy, gluten, spicy...),
  and **Statistics** that point out which foods and kinds of food tend
  to go badly (and which are fine), only once there are enough rated
  meals to tell. No reminders. In backups, Clear data and the locks.

## [1.12.0] - 2026-10-14

### Added
- To-do: an options button beside **+**: a **Waiting** list under *To
  do* (drag things you're waiting on into it and back; a tap still
  completes one; off, they show with the rest, marked with an
  hourglass), and a **Lock**: with a master password, the to-do note
  opens only while the app is unlocked (its card says *Locked*).

### Changed
- Pip's batteries: one every **5 hours** on the clock, piling up while
  the app is closed (up to 3), instead of one at a time when it's
  opened. He uses a segment every 8 hours awake (was 10).
- Charging is for fun: he uses energy as ever, but his battery doesn't
  drop while he's plugged in (it catches up when unplugged), and he
  can't run out. No lit antenna and no percentage screen.
- Ingredients list: sections have no handle shown; touch a section's
  name and move to drag it, tap it for its menu.

### Fixed
- Pip Home's *Charging* animation said he was busy when he wasn't.
- Notes: after Select all, scrolled down, the selection's handle no
  longer shows over the top bar.

## [1.11.0] - 2026-10-14

### Added
- **Pip's charging station**: while the phone is plugged in, a power
  station stands in his field; he hurries over, his hands pop in, and
  he plugs himself in (unplugged, he unplugs and it sinks back). His
  antenna lights up (brighter at night), his screen changes now and
  then (a battery filling, static, a bolt, a percentage, notes...).
  Plugged in he can't lose power; full, asleep or off he leaves it be.
  *Charging* is among his animations too.

### Changed
- Pip hurries to a battery, whatever his energy.

## [1.10.1] - 2026-10-14

### Changed
- Recipes: a card shows its prep time and type as chips.
- Ingredients list: a section's handle sits level with its name; adding
  a section has its own icon (not a folder's).

## [1.10.0] - 2026-10-14

### Changed
- Recipes: a tap on an ingredient (in Edit) gives **Quantity** and
  **Delete**; quantities are picked like Shop's (a count, a weight), or
  in **teaspoons** and **tablespoons**; holding selects several to
  remove. No quantity button on every row.
- Recipes: the recipe's options (To Shop, Duplicate, Copy, Delete) are
  under **More** at the bottom, in reach, instead of the top bar.
- Ingredients list: the first section, *Ingredients*, stays on top; new
  sections go under it; the others can be moved by their handle.

### Fixed
- Recipes: editing no longer jumps down to where the method was last
  typed after picking a type or a quantity; closing the keyboard ends
  typing in the method, as in notes.

## [1.9.0] - 2026-10-14

### Added
- **Recipes** in the Hub: recipes with their prep time, type,
  ingredients and how they're made; a recipe keeps the screen on while
  it's open; **To Shop** puts its ingredients on the Shop list; an
  **ingredients list** in sections to pick from. In backups, Clear data
  and the locks.

### Fixed
- Code blocks: the same room above and below the code; while typing in
  a block its ``` show (faint), so an emptied block can be deleted.
- Pip's batteries are blue.

## [1.8.0] - 2026-10-14

### Added
- Medicine: a medicine can be taken on **some days only** (Days → Some
  days, then the weekdays); on its other days it's under *Not today*,
  with no reminders.
- **Notification volume**: Loud, Medium or Quiet for each page's sound
  (the app's own sounds; the phone's follows the phone's volume).
- Code blocks in notes: rounded, with room around the code, in their
  own font (JetBrains Mono, part of the app: no internet needed).

### Fixed
- Medicine: holding to take an important dose fills the circle all the
  way before it pops.
- The menu: a little room between Pip's name line and his field.
- The Introduction: Pip has his own part; where the notifications-off
  notice is, the planner's reminder button, and Format's buttons put
  right.

## [1.7.0] - 2026-10-14

### Changed
- **8-bit notification sounds**: Chime, Bell and Soft are gone; pick
  from Coin, Power-up, Blip, Alert, Zap and Jingle instead (a page set to
  an old one gets the nearest new one).
- Medicine's **+** is the app's add button, as on every other page.
- A new message replaces the one showing instead of waiting behind it.
- Notes: the **code block** button (several lines of code in a panel)
  is up front on the format bar, in view without scrolling; the
  strikethrough button is gone to make room (~~text~~ still shows struck
  through).

### Added
- **Automatic backup** (Backup → Automatic backup): pick a folder once,
  and a backup is written there once a day when you open the app; the
  last 7 are kept.

### Fixed
- Medicine history: *Mark past days taken* can be undone.

## [1.6.0] - 2026-10-14

### Added
- **Pip's energy**: a battery of three segments beside his name (green,
  orange, red); he gets tired (his face, his pace) as it runs down, and
  when it's empty he turns off and falls over.
- **Batteries**: one comes every few hours when you open the app (up to
  3 held); tap his room to drop one: he walks over and picks it up. Off,
  it flies to him and he comes back on.
- **Sleep**: 23:00 to 8:00, using much less energy. Look at him between
  23:00 and midnight and he falls asleep; between 8:00 and 9:00, he
  wakes up.
- Pip Home's status shows his energy, batteries and when the next one
  comes; Animations has falling asleep and running out.
- All of it is in backups: restored, he carries on from there.

## [1.5.2] - 2026-10-14

### Changed
- Pip's night sky: fewer stars, mostly dim, none touching the moon; the
  moon is pale grey with seas, in its **real phase** (none, thin, half,
  full); the sun has rays.
- Pip Home: Pip is the same size as in the menu, in a bigger field.

## [1.5.1] - 2026-10-14

### Changed
- Pip Home: his field takes half the screen; the background is picked
  from a list (one for now, Field) instead of switched off and on.
- The menu's room is twice as high, with clouds by day.

### Fixed
- Pip Home: the rename keyboard's numbers fit on the screen, and the
  keys fit on narrow phones.

## [1.5.0] - 2026-10-13

### Added
- **Pip hatches**: the menu's room holds his egg until you tap it open:
  the first tap starts a crack, every two more widen it, and the 7th
  pops him out (with a buzz on each tap). That day is his birthday; his
  name and age show above the room. He's in backups, and keeps his real
  age when restored.
- Pip's sky follows the time of day: stars and the moon at night, the
  sun by day, dawn and dusk colours in between.
- **Pip Home**, in the Hub once he's hatched: his field, big, and a card
  you swipe between his status (name, age, birthday) and his settings:
  rename him on the card's own pixel keyboard (up to 6), play his
  animations, turn the background off or on.

## [1.4.1] - 2026-10-13

### Changed
- To-do: the **+** looks like the add button everywhere else; *Delete
  all* sits quietly beside Completed; deleting them no longer offers an
  Undo it said there isn't; done ones can't be edited.

## [1.4.0] - 2026-10-13

### Fixed
- Notes: pressing bold, italic or strikethrough again takes it off (with
  the cursor in or just after the word, or on an empty pair), instead of
  adding more symbols.
- After an update, the app could show twice in the recent apps.

### Added
- **Notifications** in the menu: the latest notifications, even after
  they're cleared from the phone (all of today's and yesterday's a tap
  away; tap one to go to it), and each page's notification settings:
  on or off, pause, private (no names on the lock screen), a sound
  (the phone's, Chime, Bell, Soft or silent) and a colour.
  The planner's can now be paused or turned off too. Medicine's settings
  moved here (its bell opens them).

### Changed
- Medicine: deleting an important medicine asks you to type DELETE.
- Medicine: when editing, the number of doses stays as it was (it mixed
  up the history); their times can still change.
- To-do: two lists, like Shop. Tapping a thing moves it down to
  **Completed** (and back); **Delete completed** clears them, with Undo.
  The note now sits under the Introduction, and its buttons are on the
  side of the hand you're using.
- Restore part of a backup: a wide **Restore** button at the bottom;
  copies of things still in the app say "(Copy)".

## [1.3.1] - 2026-10-13

### Fixed
- Notes: three backticks without a closing line no longer turn the rest
  of the note into code (it showed in 1.2.0's "What's new"). Code is a
  little smaller and easier to read, and the hidden fence lines get no
  line number.
- Notes: list dots sit level with the text.
- Notes: with the format bar open, the cursor's little pointer no longer
  sits over it.

### Changed
- Notes: the Format button shows "Tt" instead of an underlined A.
- The Introduction opens where you left it (from the top when it's new
  or restored).
- Placard: the pop sounds like a bubble popping.

## [1.3.0] - 2026-10-13

### Added
- **To-do note** at the top of Notes: a plain list. Add things with
  **+**; tap one when it's done ("Task completed", with Undo); hold one
  to change it. It can be turned off in Settings, and is in backups.
- **Restore part of a backup**: pick things from a backup (one note, a
  few shop items, a medicine with its history...) and they're added to
  what's in the app, with Undo. Nothing is replaced.

## [1.2.1] - 2026-10-13

### Changed
- Pip's screen is one row taller, less flat, in his room, in the menu's
  header and on the launcher icon (finer pixels there too, the same
  goofy look as in the room).
- Pip: standing about, he now and then turns to look the other way;
  coming out of the ground he starts fully under it.

## [1.2.0] - 2026-10-13

### Added
- **More formats in notes**: inline `code` and code blocks (between
  ``` lines, on a panel), quotes (`> `, with a bar down the side),
  highlights (`==like this==`) and dividers (`---`, a line across).
- **A format bar**: while typing, the **Format** button (where Checkbox
  was) opens a row of buttons above the keyboard: checkbox, lists,
  heading, bold, italic, strikethrough, highlight, quote, code, code
  block and divider. They format the selection or its lines, and press
  again to undo it. The keyboard stays up.

### Changed
- Notes: `####` makes a small heading (bold, a little bigger than the
  text), and list dots are a bit bigger.
- Notes: tapping the title button on a new note selects "New Note", so
  typing replaces it.
- The launcher icon is drawn as a vector, crisp at any size.
- Menu: "The App" sits level with Pip.
- Deleting the Introduction no longer shows a toast (Settings brings it
  back).
- Backup: one space between the last backup's date and time.

## [1.1.0] - 2026-10-13

### Added
- **Pip's room**: a strip of field at the bottom of the menu. The first
  time you open the menu, Pip pops out of the ground (it cracks, he
  comes up, hops and lands); then he stands about, blinks and walks
  around. Next time he's where you left him. He keeps still when the
  phone is set to remove animations.

### Fixed
- Notes: tapping in the text could select everything from the start
  instead of placing the cursor, and stay that way (the app thought
  Shift was held after the keyboard's Shift key). A touch now lets go
  of a stuck Shift.
- A list a fraction of a pixel off (e.g. the menu above Pip's room)
  could keep settling every frame, never resting.

## [1.0.0] - 2026-10-13

### Added
- **Pip** next to "The App" at the top of the menu, which now keeps the
  same height whether Lock now is shown or not (it used to shift).
- Taking an important medicine ends with a small pop and a tick, which
  stays a moment before the dialog closes.

### Changed
- Hub tiles: a locked page's small lock sits in the bottom left corner.
- Placard's pop is back to its quieter volume (the inflating stays
  louder).
- Medicine: a shorter explanation of Important.
- **The app's icon is Pip**: a little 8-bit robot with a screen for a
  face, in the Clay colours (crisp at every size, and with the face cut
  out in Android 13's themed icons).

## [0.28.0] - 2026-10-13

### Added
- **Important medicines**: set when adding or editing one. Taking a dose
  then means holding a big button for 5 seconds; it fills up like a
  glass, with a sound, and drains if you let go early. The red dot on
  the Hub only shows for important medicines (its switch is gone from
  Medicine settings).
- Settings says when the phone blocks the app's notifications, and
  asks to allow them.
- If something can't be saved (e.g. the phone's storage is full), the
  app says so, keeps the change and tries again on the next change or
  when you come back to it, and says when it's saved again.
- Reminders are planned two weeks ahead: if the app isn't opened for
  that long, a notice the evening before asks to open it, so they keep
  coming.

### Fixed
- When the app locks, a locked Hub page closes everything open over it
  too (its menu, the edit view, the hold dialog, its history).
- Two fingers on a hold button no longer restart its sound or stop it
  while one finger still holds.
- Locking from the menu (Lock now) keeps the menu open instead of
  closing it and showing the page behind; a page opened from the menu
  (e.g. Security) stays open when the app locks.

### Changed
- Medicine and Placard sounds are louder; Placard's inflate is back to
  about 3 seconds (as before 0.27.0), with the pop at full volume.
- Hub tiles: a locked page's small lock sits under the icon, centred.
- Medicine histories: back to top always on the right, and the list
  leaves room at the end so it doesn't cover the last entries.
- Medicine: adding or editing one opens a taller view that scrolls and
  closes only with back (asking if something changed); after editing,
  the medicine's menu stays open.
- Medicine settings say what stops a reminder: the dose already set as
  taken, missed or not sure.
- Doses due at the same time come as **one** notification naming them
  all (Android could hold the second one back for many minutes).
- **The app's own icon** (for now): a little pixel robot in the Clay
  colours, instead of Flutter's logo. On Android 13 and later it follows
  the phone's themed icons too.

## [0.27.0] - 2026-10-13

### Fixed
- Security: the Hub's lock switch could hide under the phone's own
  navigation bar; every list now leaves room for that bar.
- A tapped notification's "go to" is dropped when you go to another tab
  yourself (it went to Medicine later, after a detour).
- Locked notes can no longer be deleted without the master password.
- Importing a backup over locked notes asks for the master password
  first (it replaced them without it).

### Added
- **Weekly backup reminder**: Backup shows when the last backup was.
  A week after it, a red dot on the menu and on Backup, and an evening
  notification (again every 3 days until you export one) that opens
  Backup. It can be turned off on Backup.
- **Lock each Hub page on its own**: in Security, under the Hub, a
  switch per page. A locked page asks for the master password while the
  app is locked (its tile shows a small lock), whether or not the Hub
  itself is locked. Resetting a forgotten password deletes a locked
  page's data, and medicine reminders don't name the medicine while its
  page is locked.
- Medicine histories: a **back to top** button once you've scrolled far
  down.

### Changed
- Notes: **Discard changes** is always there (greyed out until there's
  something to discard), so the buttons don't shift.
- Placard: a longer inflate (about 4 seconds), and a quieter pop.
- Medicine: the total on each card is level with the drag handle.
- Settings: line numbers first.
- Security: resetting a forgotten password is harder to stumble on:
  after typing RESET, **hold** Reset for 10 seconds. A plain tap greys
  the reset out until the next unlock, or for a day.

## [0.26.0] - 2026-10-13

### Added
- **Tapping a notification opens what it's about**: a block, routine or
  reminder opens the Planner on its day, scrolled to it; a medicine opens
  the Medicine page. A locked section still asks first; if it isn't
  unlocked then, it goes there once it is.

### Changed
- Medicine: a medicine's history has a **month calendar** instead of
  the strip: weeks as rows, each day coloured by how it went (with a
  legend). Swipe right or tap ‹ for older months; tap a day to see it in
  the list below.
- Medicine: history and calendar use the same colours in every theme:
  **green** taken, **red** missed, amber not sure.
- Medicine: the **history of all medicines** is new: the medicines on
  top (tap one for its own history), then each day as a small table, a
  row per medicine with a mark per dose. Tapping a row opens that
  medicine's history at that day, where doses can be set. Ready for years
  of history.
- Medicine: unticking a dose asks first (a slip of the finger); each
  card shows how many doses were taken in all.
- Medicine: late doses on the main page are no longer red (that was
  meant for the calendar).
- Placard: the inflating sound is just the rising tone, no static.
- Planner: the hour labels a touch further from the edge.
- Planner: reminder marks a bit bigger, midway between the hour and the
  timeline. Two reminders share a mark only when they'd overlap (about
  12 minutes apart, not 27); close ones each keep their own, and a tap
  goes to the nearer one.
- Counters: the first click after opening is in step with its buzz.

## [0.25.0] - 2026-10-13

### Fixed
- Medicine: the red dot showed after midnight for any dose missed the
  day before; now only for doses at 22:00 or later (until 02:00).
- Pages opened on top (like the Introduction) leave room for the phone's
  own bar too, so their last lines scroll clear of the buttons.

### Changed
- Medicine: **Remind again** is now set for each medicine, in its sheet
  (No, or 1–4 h later), instead of once for the whole page. Its menu
  shows it. (Backups now have format 13.) If you had set it for the
  page, set it again on the medicines that need it.
- The Introduction is no longer in the menu (it lives in Notes); once
  deleted, **Settings → Restore the introduction** puts it back.
- Medicine: a dose whose time has come and isn't taken shows in **red**.
- Medicine: ticking a dose buzzes twice, softly, in step with the gulp.
- Routines screen: reach mode on its timeline, as on the planner.
- Planner: a smaller margin left of the hour labels.
- Placard: the pop no longer shrinks first: it bursts from fully
  inflated, with a ring flying out, and springs back. A rising sound
  while you hold, and a pop.

## [0.24.0] - 2026-10-12

### Fixed
- Notes: the lines level with the buttons at the bottom were hidden
  (e.g. after redo they looked missing), and tapping there jumped the
  text. Now nothing covers the text, taps beside the buttons reach it,
  and the line you're on scrolls up clear of the buttons.
- Planner: the hour labels have their margin from the screen's edge
  back.
- Notes: checkboxes are now drawn by the app, so both look right on
  every phone: an outlined square, or a filled one with a tick, in the
  accent, the same size.

### Added
- An **Introduction** at the top of Notes: how each part of the app
  works, and what's new in this version. It comes back marked *New*
  after each update (Settings can turn that off); delete it from its
  page, and open it any time from the menu.
- Planner and routine sheets: an **End of day** choice for the end time.

### Changed
- Medicine: ticking a dose plays a soft **gulp** instead of the chime.
- Counters: the click is quieter and follows the **media volume**.
- Placard: the hold to count is longer again (about 3 seconds).
- Routines screen: a new routine starts where you tap the free time, as
  on the planner.
- Medicine: "Mark past days taken" is offered only when more than 10
  past doses aren't set.
- No tooltip pops up when holding a button (e.g. − in the shop).
- Notes: no magnifier lens while selecting text.
- Medicine: a dose missed late in the evening keeps the red dot until
  02:00.

## [0.23.0] - 2026-10-12

### Added
- Medicine: **reminders** at each dose time, and if you like a second
  one 1–4 hours later while it's still not taken. A **red dot** on the
  Medicine tile and the Hub tab while one of today's doses is due (shown
  even when the Hub is locked). Both can be turned off or **paused** for
  a day or more in Medicine's new **settings** (the gear in its top bar).
  Medicine reminders have their own channel in Android's notification
  settings.
- Medicine: **history you can read and fix**. Each day has a coloured
  title and a mark per dose; tap one to set it taken, missed or not sure.
  Each medicine has its **own history** (in its menu): the total taken
  so far, a calendar strip of its days (scroll left for older ones) and
  every day below. A medicine can **start in the past**: you're asked
  whether to mark those days taken, and its history has a button for it
  too. (Backups now have format 12.)

### Fixed
- Planner: screen readers can add a task from free time again (it had
  no tap action).
- Planner sheet: ticking a weekday that clashes no longer pushes the
  form down (the chip you tapped stays where it was). The clash line
  looks like the info line, in red, and **Find a free time** is a real
  button.
- Notes: the ticked checkbox showed as a white emoji, and the empty one
  sat higher; both are now drawn the same, in the accent, without a jump
  when ticking.

### Changed
- Medicine: ticking a dose plays a short chime and buzzes (no undo when
  unticking: just tap again). Doses sit two to a row, all the same
  width; a tap anywhere on a card opens it; drag a card's handle to move
  it; the buttons are always on the right; no "for good" written.
- Planner: a new block starts **where you tap** the free time (rounded
  down to :00 or :30), and tapping the **left edge**, by the hour labels,
  adds a reminder there (rounded down to 15 minutes).
- Planner: **reach mode** on the timeline. At 00:00, pull down again and
  the first hours come into thumb reach; push up and it snaps back.
- Placard: the hold to count is longer (about 2½ seconds).
- Counters are more compact and all the same height; − / + are in the
  counter's own colour, vivid (the colour also edges the card), or the
  app's grey without one. No "none" hint in Min / Max.

## [0.22.0] - 2026-10-12

### Changed
- **Other is now called Hub** (a section lock or tile order you had
  carries over).

### Added
- Hub: **Medicine**. Add your medicines with the time of each dose and
  how long you take them; tap a dose when you've taken it (the time is
  kept). Several a day show as 1 of 2. History lists every day. (In
  backups, now format 11.)
- Counters: **options**. A new counter (or Edit, in selection mode) has
  a step (− / + count by it), a colour and optional min and max; the
  buttons stop at the limits. Cards look rounder, with room around them.
  (Backups now have format 10.)
- Hub: **Placard**. A big line of text, sideways and full screen, with
  a count: hold the page and it inflates, shakes and pops to count one
  up. Five taps in the top-right corner set the text and the count. (In
  backups, now format 9.)
- Hub: **hold a tile and drag it** to change the order (kept).
- Settings → Clear data lists the Hub's pages one by one.

## [0.21.0] - 2026-10-12

### Added
- Shop: **amounts**. The new button on an item switches between none, a
  count and a weight; tap the amount for big − / + (weights step through
  common amounts, from 200 g) or to type an exact weight. (Backups now
  have format 8; older ones restore as before.)
- Planner: **reminders are small bell marks** on the timeline's left
  edge instead of boxes over the blocks. Close ones share a mark with a
  number; tap a mark to see them, tick them off or edit them.
- Five more themes, all dark: **Ocean**, **Frost**, **Grape**, **Rose**
  and **Mono**.

### Changed
- Messages at the bottom (like "… deleted · Undo") are a rounded card
  in the theme's colours, floating above the buttons.
- Planner sheet: a time that runs into another block is **no longer
  moved by itself**. It stays, in red, Save is off, and a **Find a free
  time** button moves it if you want.
- **Clay** is first in Themes and the default for a new install. Its
  orange text buttons are a touch lighter, to read better.
- Notes: the Checkbox button is a small one beside *Edit title*, shown
  only while typing. The empty box is bigger, and both boxes are in the
  theme's accent colour.
- Settings → Clear data: confirm by typing DELETE; the Clear button is
  just text.

### Fixed
- Editing a routine: Save sits right at the edge again (since Delete
  moved left it stopped short).

## [0.20.0] - 2026-10-12

### Added
- Notes: **checkboxes**. Type `- [ ] ` (or use the new Checkbox button
  next to ↶) and it shows as a box; tap the box to tick it. Enter starts
  the next one.
- Planner: a **now line** across today's timeline at the current time.
- Settings → **Clear data**: pick Notes, Shop, Planner and/or Other and
  empty them, after typing RESET and entering the master password (if
  one is set). Backups are not touched.

### Changed
- Notes: tapping outside the *Save changes?* dialog only closes it and
  you stay in the note (back on the dialog still saves and leaves).
- Planner sheet: no ✕ (back closes it, asking first if something
  changed); editing a routine has a plain **Delete** on the left.
- Planner: short blocks show a line of their description too, down to
  the smallest.

### Fixed
- Coming back after the auto-lock no longer shows the locked page for
  a moment: the app is covered as it leaves while unlocked.
- No button flashes when it becomes available anymore (it happened on
  the planner's Add): the fix now covers every button in the app.

## [0.19.0] - 2026-10-12

### Added
- Planner: tasks and routines can have a **description**. It shows on
  the block under the time when there's room, and in full when you tap
  the block. (Backups now have format 7; older ones restore as before.)

### Changed
- Planner: tapping a task shows what it is first (time, colour,
  reminder) with Edit and Delete (with Undo), like a routine; editing
  doesn't open the keyboard straight away.
- Planner: Add / Save stay greyed out until there's a title.
- Planner: four more colours (teal, pink, brown, grey); new tasks start
  blue and new routines purple.
- Notes: a note with no title and nothing in it goes away when you
  leave it, also one that was emptied by editing (back still asks first,
  so the change can be discarded).
- Switching tabs ends selection mode, and coming back to the Planner
  shows today (a selection or a picked day used to linger).
- Planner: a short block (say a 5-minute shower) is now drawn full size,
  and its hour on the timeline gets a bit taller to make room, instead
  of the block being squeezed.

### Removed
- The planner's zoom button: short blocks no longer need it.
- The Džoni page in Other. Its count is no longer kept; older backups that
  have it still restore.

## [0.18.0] - 2026-10-11

### Added
- **A task and a routine can share time**: side by side, the task on
  the left and the routine on the right; where one goes on alone it
  takes the full width. Tapping a routine has a new *Add a task
  alongside*. (Before, a task pushed the routine off that day.) Two
  tasks, or two routines, still can't overlap. The quick end in the
  sheet now reads *Until the next task* (or routine, or midnight).
- **Reminders on the planner**: the bell button at the bottom adds a
  reminder: a title and a time, no end. It floats over the timeline as a
  small dashed block without taking up time, notifies at its time, and
  goes away when you tick it off (with undo). Tap it to change or delete
  it. Included in backups.
- **Planner zoom**: a button at the bottom (also on Routines) makes the
  timeline bigger in two steps, so even a 5-minute block can be read and
  ticked, then back to normal. It's remembered. Blocks are now at least
  5 minutes long.

### Changed
- **Notes open for viewing**: tap the text to edit it there. Back (or
  closing the keyboard) while editing goes back to viewing; back again
  leaves. The ← arrow at the top always leaves.
- List bullets show as dots (•), except on the line you're editing.
- Menu: *Lock now* is an icon at the top right (it stays put), and
  *Themes* comes before *Backup*.
- Setting a password: the keyboard's next key goes to the next field.
- A locked note shows a lock icon next to "Note" instead of "Locked
  note".
- *Edit title* changes the title as you type, and it can be left empty.
- Selection mode has no ✕ button anywhere: back, or deselecting all,
  leaves it.
- Other: new icons for the tiles (tally marks for Counters, a speech
  bubble for Džoni).
- Shop: a cart icon marks what's to buy and a tick what's bought,
  instead of checkboxes.
- Shop: the select button first selects the list you started in, then
  both lists, then nothing.
- Planner: more space between blocks that touch (an hour is a bit
  taller, so a 30-minute block is still a full touch target); a bell on
  blocks with a reminder; when a picked time had to change to fit, the
  sheet says why.
- Selected items have a much clearer outline everywhere.
- Planner sheet: it no longer closes when dragged down; pulling down
  brings the form into thumb reach. A ✕ at the bottom closes it, and if
  something changed it asks first (back on that question discards).

### Fixed
- Planner notifications show a proper bell icon instead of a grey blob.
- Planner: ticking another weekday (or changing the end date) in a
  routine's sheet now moves its times clear of other routines on those
  days and says so. Before, the clash only showed after saving, and the
  changes were lost.
- If the phone can't save (e.g. its storage is full), removing, changing
  or resetting the master password now stops and says so, instead of
  going ahead with data that wasn't saved.
- Data that can't be read at startup is still kept aside (never
  overwritten), and now the app says which.
- Resetting a forgotten password with the Planner locked also deletes its
  reminders.
- Planner: left open overnight, it still showed yesterday as today until
  something changed. It now catches up when the app comes back.
- Notes: pressing Enter at the very start of a note works again.
- Notes: if the app locked while *Save changes?* was open (with Notes
  locked), it could end on a black screen. It now saves and goes back to
  the lock screen.
- Notes: only moving the cursor no longer rewrites the notes file.
- Planner notifications: two quick changes could leave a notification
  for something already ticked off or deleted. They're now planned one
  at a time.
- Planner: adding a task in the last minutes before another one no
  longer makes a block shorter than 5 minutes, and an old short block
  can be edited without its times getting stuck.
- Planner: a reminder can be at any minute, up to 23:59.
- Planner: while selecting, checkboxes don't tick anything.
- The Reset button in *Forgot password* no longer flashes when it
  becomes available.
- Planner: a long-pressed block now shows as selected (it was selected,
  but didn't look it until something else redrew the day).
- **Counters click again**: the app plays its own click; Android's touch
  sound (which it used before) is off on most phones.

## [0.17.0] - 2026-10-11

### Added
- **Planner routines**: blocks that repeat every day, on weekdays or on
  chosen days, for good or until a date. Set Repeat when adding a task,
  or use the new **Routines** screen (button at the bottom of the
  planner; a Mon–Sun strip picks the weekday). On a day, tap a routine's
  block to change it just there, skip that day, or edit the routine;
  ticking it off counts for that day only. A one-off task already in its
  way wins that day.
- **Planner reminders**: in the task or routine sheet, *Remind* at the
  start or 5–60 minutes before. A notification with the title and time
  (only "Planner" and the time while the Planner section is locked).
  Notifications permission is asked the first time.
- **Block colours** in the planner: pick one of six colours (or none) in
  the task or routine sheet; the block gets a tinted background and a
  coloured stripe.

### Changed
- **The menu stays open** when you come back from one of its pages; back
  again closes it.
- Counters: selection mode has no ✕ button any more (back leaves it).
- Notes: ↶ Undo and ↷ Redo stay in that order when the buttons are on
  the left.
- Planner: an hour is a little taller, so even a 30-minute block (and
  its checkbox) is a full touch target; the task sheet's times are
  outlined buttons, readable in every theme.

## [0.16.0] - 2026-10-10

### Added
- **Line numbers in notes**, like a code editor (one per paragraph). Turn
  them off in Settings.

### Changed
- **Markdown symbols hide** once formatted: `##`, `**` and the rest only
  show on the line you're editing.

## [0.15.0] - 2026-10-10

### Added
- **Markdown in notes, styled as you type**: `- ` and `1. ` lists (Enter
  continues them, Enter on an empty item ends the list), `#`–`###`
  headings, `**bold**`, `*italic*`, `~~strike~~`. Notes stay plain text.
- **Unlock with fingerprint** (Security): instead of typing the master
  password, wherever the app asks for it. Kept on this phone only, in
  Android's keystore; turns itself off when the master password changes.
  The app now needs Android 6 or newer.
- **Edit title** button in the note editor: a smaller button above the
  others opens the title in a sheet at the bottom, within thumb reach.
- Džoni: the page has no top bar; a triple tap in the top-right corner
  sets or resets the count.

### Changed
- **Note editor buttons**: Lock note (or Remove lock) is a button of its
  own instead of a ⋮ menu, and ↶ Undo / ↷ Redo sit outermost, under the
  thumb. Tapping them no longer closes the keyboard.
- **Planner free time is a block too**: see-through, with a dotted
  border, lined up with the task blocks.
- **Reach mode reaches further** (about one row more; Counters a bit
  more again).
- **Shop scrolls to each new item** as you add it, so you see it land in
  the list above the add sheet.

### Fixed
- **Reach mode snaps back as soon as you let go**: a small scroll the
  other way used to coast, and only snapped back on your next touch.

## [0.14.0] - 2026-10-10

### Added
- **Undo / redo in notes**: ↶ and ↷ buttons in the editor go back and
  forward step by step (a burst of typing, or a paste, is one step).
  Discard changes can be undone too.
- **Forgot master password?** on the Security page: resets it by deleting
  what it locks (locked notes, and everything in locked sections).
  Everything else stays. The confirmation lists what goes and asks you to
  type RESET.
- **Edit planner tasks**: tap a block to change its title or times (up to
  the tasks around it).

### Changed
- On today, a new planner task starts at the next full hour instead of
  at the start of the free time.
- The planner's 00:00 label is no longer cut off at the top of the day.
- Changing the theme no longer flashes the old one for a moment.
- **Reach mode in the menu and on every list page** (Security, Backup,
  Themes, Settings): pull down at the top to bring the first items
  within reach.
- **Swipe right along the bottom bar** to open the menu.
- **Clay** looks more like the Claude app: near-black background and
  Claude's deeper orange.
- **Planner day strip previews live**: while you swipe, the day in the
  middle (now framed) is shown at once, not only when you let go.
- **Reach mode replaces the pull-down space**: pull a list down when it's
  already at the top to shift it down (by less than before) so the first
  rows are in thumb reach; any scroll the other way snaps it back.
  Scrolling up from further down just stops at the top.

## [0.13.0] - 2026-10-10

### Added
- **Planner time blocks**: each day is a timeline from 00:00 to 24:00.
  Tap free time to add a task there — it starts where the free time
  starts and lasts an hour, or pick 15 / 30 min, 1 / 2 h, *until free
  time ends*, or a time. Tasks never overlap; tick them off with the
  checkbox in the block's corner. (There's no + button anymore.)
- **Themes** (Menu → Themes): Green (the original look), Black (true
  black for OLED screens) and Clay (warm greys with a clay-orange accent).
- **Settings** (Menu → Settings): switch the counters' click and
  vibration on or off.
- **Counters click and vibrate** on − and +.
- **Džoni** in Other: a sideways page with a big question and a count —
  hold anywhere to count one up.

### Changed
- **Actions sit at the bottom, on your hand's side.** Selection mode and
  the note editor show their buttons at the bottom right — or bottom left
  if you tapped on the left half of the screen to bring them up. Top bars
  keep only ☰ (or ←). Selection's ✕ is now the outermost bottom button.
- In the note editor, *Discard changes* has a new icon and only appears
  once there's something to discard; ⋮ is at the bottom too, and the text
  ends above the buttons.
- **Other** shows its tools as icon tiles, starting in the bottom right.
- Backups also keep the Džoni count (backup format 4; older backups
  still restore).
- **Planner**: a fast swipe on the day strip travels many days; the past
  is greyed out (only back to the oldest unfinished task); no Today
  button.
- Lists settle at the top when you scroll back up close to it, and going
  to a section puts its list back at the top.
- The drag handle area is a little smaller.
- **No touch ripples** anymore.

## [0.12.0] - 2026-10-09

### Added
- **Planner**: a to-do list per day. Swipe or tap the day strip at the
  bottom to pick a day (today is outlined, days with tasks have a dot);
  + adds tasks to that day; tap a task to tick it off. Long-press to
  select and delete; drag to reorder. Included in backups.
- **Counters** (Other → Counters): named counters with big − and + buttons.
  Long-press to rename, reset or delete; drag to reorder. Included in
  backups.
- **Section locks** (Menu → Security): switch on a lock for Notes, Shop,
  Planner or Other. While the app is locked, a locked section shows a lock
  screen instead of its content; enter the master password to open it.
  Turning a lock off needs the password too. A section lock hides the
  section — to encrypt content, lock notes.

### Changed
- **Easier one-handed use**:
  - The drag handle reacts on the whole area around it (full row height,
    wider to the left), not only on the icon.
  - In selection mode, *Select all*, *Delete* (and *Lock* for notes) are
    round buttons in the lower right instead of the top bar.
  - Lists can be pulled down past their top, so the first rows come
    within thumb reach; scroll back up to return.
- **Shop order**: new items, and items moved back from *Items*, now go to
  the end of *To buy*, so the list keeps the order you added things in.
  Bought items still go to the top of *Items*.
- **Touch feedback**: rows and buttons all show the same plain ripple.
  Tapping a shop item's checkbox now ripples the whole row, like tapping
  the item.

## [0.11.0] - 2026-10-09

### Added
- **Locked notes**: lock a note from its ⋮ menu (or several in selection
  mode). Its content is stored encrypted with your master password; the
  title stays visible in the list with a lock icon. Opening it asks for
  the master password if the app is locked. **Remove lock** turns it back
  into a normal note. Without a master password, locking first helps you
  set one.
- **Backups keep locked notes locked**: they stay encrypted inside every
  backup file. Restoring on a phone without a master password takes over
  the backup's; otherwise the backup's password is asked once (not at all
  for a backup from this phone) and the notes then open with yours.
- **Unlock once**: after entering the master password, the app stays
  unlocked while you use it and during short trips to other apps. It locks
  again after 5 minutes in the background, when the app is closed, or with
  **Lock now** (in the menu and on the Security page).
- Encrypted export no longer asks for the password while unlocked.

- **Press back twice to exit**: on a main section, the first back shows
  "Press back again to exit"; back still closes the menu or leaves
  selection mode first.

### Changed
- Removing the master password unlocks all locked notes first (the form
  says how many), so none are ever left without a password.
- Setting a master password also unlocks the app.
- **Dialogs redesigned**: clearer title, message and buttons, with squarer
  corners. Leaving a note now asks with **Discard** and **Save** buttons
  and says that notes are saved automatically.
- Data files from a newer app version (only possible after installing an
  older version) are set aside untouched instead of being read.

### Fixed
- Creating a note no longer makes the notes list jump while the editor
  opens.
- Closing the keyboard while adding shop items now closes the add field
  too, instead of leaving it over a dimmed page.

## [0.10.0] - 2026-10-08

### Added
- **Import from file** (Menu → Backup): pick a backup, enter its master
  password if it's encrypted, see what it holds (date, number of notes and
  shop items) and confirm to restore it. Files that aren't backups, are
  damaged, or come from a newer app version are refused with a clear
  message, and nothing changes. **Undo** right after restoring puts your
  previous data back.

## [0.9.0] - 2026-10-08

### Added
- **Encrypted backups**: Export now asks *Plain file* or *Encrypted file*.
  An encrypted backup can only be read with your master password (you
  confirm it when exporting) and is named `…-encrypted.json`. Needs a
  master password; without one the option points you to Security.

## [0.8.0] - 2026-10-08

### Added
- **Master password** (Menu → Security): set, change and remove it.
  It's never stored — only a check value derived from it with Argon2id —
  so a forgotten password can't be recovered. It will protect locked
  notes and encrypted backups.

## [0.7.0] - 2026-10-08

### Added
- **Backup → Export all data** in the menu: saves your notes and shopping
  list to one file (e.g. `the-app-backup-2026-10-08-0930.json`) wherever
  you choose — Downloads, Google Drive, … Importing it back comes next.

## [0.6.0] - 2026-10-08

### Changed
- **Compact shop rows**: about 20% more items fit on screen, while every
  row stays a full-size touch target.

### Fixed
- Screen readers (TalkBack) now announce shop items with their name and
  checked state, and announce selected rows in selection mode; drag
  handles are no longer read out as "Reorder".
- Selecting a row no longer makes it 2 px taller.

## [0.5.0] - 2026-10-08

### Changed
- **Back from a note asks "Save changes?"** when something was changed
  (*Save new note?* for a new one). **Yes** — or tapping outside the dialog
  — keeps the changes; **No** puts the note back as it was, or deletes the
  new note. Back without changes leaves straight away. Closing the app
  still saves everything, without asking.
- **↶** now only appears on existing notes and keeps you in the note after
  undoing your changes.

## [0.4.0] - 2026-10-08

### Added
- **Discard changes** (↶ in a note's top bar): undoes everything done since
  the note was opened, even after it was autosaved, and closes the note.
  A note created in that session is deleted instead. Asks first.

## [0.3.1] - 2026-10-08

### Fixed
- Android build failed in 0.3.0: the version-info plugin needed a newer
  Kotlin than the project uses; now uses a compatible plugin version.

## [0.3.0] - 2026-10-08

### Changed
- The gear icon and Settings page are replaced by a **menu** (☰, top
  left on every section) with a **Security** page — master password and
  section locks arrive in upcoming versions.
- The app version is shown at the bottom of the menu.

## [0.2.0] - 2026-10-08

### Added
- Settings page, opened from the gear icon on every section (Security and
  Backup are listed and arrive in upcoming versions).
- **Other** section, where extra tools such as Counters will live.

### Changed
- The To Do section is now called **Planner**.
- The unfinished Export/Import menu on Notes is gone; backup will live in
  Settings.
- Back on any main section closes the app; back from Settings or a note
  returns to where you were.

## [0.1.0] - 2026-10-07

First tracked release.

### Added
- Notes: create, edit title and body, custom order with drag handles,
  long-press selection with confirmed delete. New notes start as
  "New Note" and are removed again if left untouched.
- Shop: "To buy" and "Items" lists; tap moves an item between them; add
  several items in a row; drag to reorder; selection with confirmed delete.
- To Do tab placeholder.
- All data is saved on the phone after every change; note edits are
  autosaved while typing and when the app goes to the background.
