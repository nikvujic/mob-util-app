# Pip's quests — spec (Round 121)

Written in Round 121, after v2.0.0; Round 122: the house drawn again, more detailed, nothing floating; Round 123: the fireplace inside, a larger porch, the forest, the mine and the beach; Round 124: the house area's own tall tree, wooden stairs, a denser forest, the mine in a mountain. The first quest is **Build a house**:
Pip gathers wood, stone and sand, makes glass, and builds a house piece by
piece over about two months, during two set hours a day. The house then
becomes where he lives. **Requested** marks what was asked for,
**Decided** an answer to a question, **Proposed** what was filled in;
what's still open is in section 13. Drafts: `docs/pip_house_drafts.png`.

## 1. What a quest is

- **Requested:** a new kind of idling, with **progression**. A quest is
  long: it may take him **months**.
- **Requested:** one quest is offered at a time, as a chain: once the
  house is built, the next is *decorate / furnish it* (later: **Build a
  bed**, section 12).
- **Requested:** a quest **can't be cancelled** once started.
- **Requested:** a quest has a **name** ("Build a house") and, once done,
  a **picture**: a framed snapshot of it. **Decided:** a drawn picture of
  the finished house in a little frame (the same every time), not a
  screenshot.
- **Proposed:** he works the same whether you're watching or not: the
  work is worked out from the clock (section 4), and watching only shows
  it.

## 2. Quest hours

- **Requested:** every day **10:00–11:30** and **19:00–20:30** (local
  time): three hours a day.
- These fit around his day as it is: asleep 23:00–8:00, adventures
  12:00–18:00. The field keeps 8:00–10:00, 11:30–12:00, 18:00–19:00 and
  20:30–23:00.
- **Requested:** a quest can be **started only during quest hours** (as
  an adventure is registered only in its hours). Started, he sets to work
  at once, for what's left of that window.
- **Requested:** **no quest work on a ski trip**; he picks up where he
  left off when he's back.

## 3. Pip Home: the Quests button, the inventory card

- **Requested:** a **Quests** button under **Adventures**. Like
  Adventures, it changes what the **info card** shows; it doesn't open a
  page.
- **The Quests card:**
  - **Offered** (none active): the quest's name, a line about it, and
    **Start**. Outside quest hours Start is greyed: *Starts between 10:00
    and 11:30, or 19:00 and 20:30*.
  - **Active:** the name, a progress bar, what he's on now (*Chopping
    wood: 37 of 264 wood*, *Laying the floor: 5 of 12 planks*), and
    roughly when he'll finish (*about 3 December*). Proposed: the
    finish date assumes no days lost; days powered down push it on.
  - **Completed:** below, each done quest as its framed picture with its
    name and the date it was finished.
- **Requested:** an **inventory card** to the right of the info card:
  swiping from the info card goes **info → inventory → animations** (the
  animations preview stays last). It shows what he carries: **wood,
  stone, sand, glass**, each as a small pixel icon with a count. Empty:
  *Nothing yet*.
- **Proposed:** the inventory card shows the quest materials only for
  now; later quests add theirs (wool for the bed).

## 4. The script: work worked out from the clock

- **Requested:** what he does is **set in advance**, so whenever the app
  is opened during quest hours he's shown at the right point of his work,
  watched or not.
- **Proposed:** the quest is a fixed **script**: a list of steps, each
  taking a set number of **work minutes**: walk out, chop a tree (wood
  +4), walk back, lay a plank (wood −2), and so on (sections 5 and 6).
- **Work minutes** are the minutes inside quest hours since the quest
  began, **minus** the minutes he was **powered down** or **on a trip**.
  They're kept the way an adventure's minutes are: stored, and brought
  up to date whenever the app looks at his life, so days the app wasn't
  opened are counted too.
- From the work minutes alone come **which step he's on**, **how far
  into it** he is, **what's built** and **what's in his inventory**. A
  window ending mid-step just stops there; the next window carries on
  from the same point.
- **Requested:** the whole house takes about **two months** of work:
  60 days × 180 minutes ≈ **10,800 work minutes**. The script's minutes
  are tuned to that, with a test that holds the total between 55 and 65
  days.
- **Proposed:** within a window he's never idle: a step that can't start
  (materials short) is never in the script, because the script always
  gathers before it builds.

## 5. Materials

| Material | Where | How (animation) |
|---|---|---|
| **Wood** | **The forest** (Round 123; Round 124: denser, three layers of trees, the far ones hazy): oaks, birches and pines as on his field, bushes, ferns, mushrooms, old stumps | He walks out, the ground scrolling, into the forest. He strikes a tree with his sword until it creaks and falls; it breaks into logs that fly to him and drop into his inventory, leaving a stump. A tree gives 4 wood. |
| **Stone** | **The mine** (Round 124): **a mountain** rising up the right of the screen and off its top (rock in bands, ore glints, ledges, pines on its slope, snow up high, hazy peaks behind), a timber-framed mouth at its foot with a lantern, rails and a cart | The same walk; he strikes a boulder by the mine until a block cracks off, chips flying; the block flies to him. |
| **Sand** | **The beach** (Round 123): the sea to the horizon, waves foaming onto wet sand, shells, a starfish, beach grass, his bucket | He digs; sand flies to him in little heaps. |
| **Glass** | His **fireplace**, in the house | Two sand and a wood (the fire) go into a crucible in the fire; it glows; a pane comes out. |

- **Requested (Round 123):** no furnace outside: a **stone fireplace in
  the house**, against the back wall on the left, is where he smelts
  sand into glass (and later, warmth and light).
- **Proposed:** a trip out gathers until he carries a load (about a
  dozen of a thing), then he walks back. Times are set so a tree takes a
  good while to fell (he's small, it's big). They're tuned in the rules
  round to the two months.

## 6. The house, built piece by piece

- **Requested:** the house is on **its own screen**, his **house area**
  (the background always the same, **one tree**: **Requested (Round
  124):** a **tree of its own**, taller than the field's (the house is
  big), in the field trees' style and colours, **following the
  seasons**: blossom in spring, green in summer, orange in autumn, bare
  with snow on its branches in winter), the house **big**, on
  the **left** of it. **Requested:** he leaves the house area by its
  **right edge** and appears on the field (section 7).
- **Requested:** so big that the **menu's strip can't show it all**:
  the strip shows where he works (the floor and walls); the **roof shows
  only in Pip Home's taller scene**.
- **Requested:** **every part built**, each costing its materials, no
  interior. **Requested:** stone, wood and glass; **detailed and
  sound**, since it becomes where he lives.
- Seen from the side, cut away at the front, so he's seen inside.
- **Requested (Round 122): nothing floats.** Every block rests on what's
  under it: built bottom-up, row by row, each on the ground or on a
  block already in place. Only materials flying to him or into a piece
  are in the air.
- **Requested (Round 122):** detailed, like **a good-looking Terraria
  house**: textured stone bricks (mortar, shades), plank grain, dark
  log beams, multi-pane windows with sills, a banded door under a stone
  lintel, a porch with a railing, eaves with trim, a gable with a round
  attic window, flower boxes. **Round 123:** no stone along the outside
  wall: the chimney is the fireplace's flue, inside, up through the
  roof; and **a larger porch** (a deck, its own roof on two posts, a
  railing, a bench, the lantern). **Round 124:** the deck stands on
  wooden posts on small stone pads, and **wooden stairs** (treads, a
  stringer, a handrail) go down from it, no stone slab.
- **The order (decided, Round 122):**
  1. **Stone foundation**, block by block, the bottom row first.
  2. The **porch's posts** (on stone pads), its **deck** and the **wooden
     stairs** down from it.
  3. **Wooden floor**, plank by plank.
  4. **The fireplace's hearth** (stone), on the foundation.
  5. (the hearth is ready: from here glass can be smelted)
  6. **Posts** (log beams): the corners and the middle.
  7. **Walls**: the back wall and the side walls, row by row from the
     floor up, leaving the window openings and the doorway.
  8. **Glass**: smelted in the fireplace, then the **two windows** set in
     (frames, four panes each, stone sills).
  9. **The door** (planks, iron bands, a handle) under a **stone lintel**;
     the porch **railing** and post, the **lantern** hung on it.
  10. **The ceiling beam** across the posts; the fireplace's **flue**
      raised on it, block on block, the porch's posts and beam.
  11. **Scaffold** (wood) put up, to reach the top.
  12. **Rafters**, then the **gable** (planks, the round attic window).
  13. **Shingles**, row by row from the eaves up to the ridge.
  14. The **porch roof** and **bench**; **eave trim**, the flue's cap,
      **flower boxes** under the windows.
  15. **Scaffold taken down**; done.
- **Requested:** building is shown: he **walks to the piece**, its
  materials **fly from him into it**, and it **smokes / puffs** while he
  works until it's in place. For high parts he climbs the scaffold.
- **Proposed:** a piece being built shows as a dotted outline that fills
  in as he works.
- **Proposed:** the tree, rock and sand drawn as in the drafts or better:
  a layered canopy with branches, bark and roots; boulders with cracks,
  light and moss; a dune with ripples. A felled tree leaves a stump.

## 7. Moving between places

- **House area** (fixed, the floor doesn't move): he leaves by the
  **right edge** and appears on the **field** (his usual one).
- **Out gathering**: on the field he walks to the middle and keeps
  walking, the ground scrolling, until the tree (rock, sand) comes in
  from the right; then he works. Done, he turns and walks off the left
  edge and appears in the house area from the right.
- **Proposed:** these walks are steps of the script too (a few minutes
  each), so the clock always knows where he is.
- At the end of a window he stops where he is, walks back to the field
  (if he's in the house area, out its right edge) and idles as usual.
  Next window he walks back to his work.

## 8. What can interrupt him

- **Requested:** nothing during quest hours but a **medicine reminder**
  or **powering down**.
- **Proposed:** the random events (bugs, butterflies, the ball, flowers,
  notifications shown on his screen, coming in from the sky or the side)
  **don't happen** during quest hours.
- **Medicine:** when its reminder's up he stops, shows the pill (as on
  the field), then goes back to work. **Proposed:** the work minutes
  don't pause for it (it's a few seconds shown, not lost work).
- **Powered down:** he falls **where he is** (in the forest mid-chop, on
  the scaffold's foot); **Requested:** where the clock says he fell.
  Those minutes aren't work. A battery during quest hours brings him back
  up, and he carries on from the same point.
- **Decided:** **no charging during quest hours**: plugging the phone in
  doesn't send him to his charging station (he's moving between places).
  After quest hours, if it's still plugged in, he goes as usual.
- **Batteries:** tapping to give one works wherever he is.
- **Ski trip:** no work (section 2).

## 9. Weather and seasons

- **Decided:** in **rain, snow or a thunderstorm** he wears a **rain
  hat** while he works (out gathering and at the house). His hats for
  occasions give way to it while it's wet.
- **Requested:** **rain** with the roof **started but not finished**:
  it **leaks**, drips falling inside and a puddle growing on the floor.
  No roof started: the rain simply falls in.
- **Requested:** **snow** piles on a house that isn't finished: caps on
  the top edges of what's built, a drift on the floor while there's no
  roof.
- **Proposed:**
  - **Thunderstorm:** lightning flashes as on the field; he keeps
    working.
  - **Wind:** the scaffold sways a little, sawdust and smoke blow
    sideways, the house area's tree sways as on the field.
  - **Fog:** the scene greys, as on the field.
  - **Night:** the evening window is dark in winter: **a lantern** hangs
    from the house (on its post while there are no walls), lighting
    where he works; out gathering he carries it.
  - **Seasons:** the house area's tree and grass follow the season, snow
    on the ground in winter.
  - **Occasions:** Halloween, a jack-o'-lantern by the steps; New Year's
    Eve, lights along the eaves once there's a roof (on the tree before);
    Christmas, the badnjak by the door; Easter, painted eggs in the grass.

## 10. Once the house is built

- **Requested:** the house becomes his **new idling area**, with its
  own events (more to come later); some events stay, some stop (**the
  bug attacks don't happen there**).
- **Requested:** he **sleeps inside** the house.
- **Requested:** he's still **out on the field 11:30–12:00 and
  18:00–19:00** (out of the house), with its usual events.
- **Decided:** his **charging station** appears where he is: in the
  house (outside it, on the grass, if the house area's view leaves some
  grass outside the house), or on the field when he's there.
- **Proposed:** events that stay in the house: his screen showing
  notifications, the medicine reminder, hats, falling asleep and waking
  up, looking out of the window at the weather. Events that stop there:
  bugs, butterflies, flowers, the ball, puddles, the snowman, snowballs.
- **Proposed:** with no quest active, quest hours are ordinary house
  time.
- **Decided (Round 122): adventures stay as they are**: once registered
  he's out every day 12:00–18:00. He isn't only when powered down at
  12:00 with no battery until 17:00 (he lies where he fell, then idles
  in the house), or on a ski trip (he's skiing).

## 11. Data and backup

- **Proposed:** in `pip.json` (version 4): the active quest (its id,
  when it began, its work minutes and up to when they're counted) and
  the completed quests (id, finished at). Backups carry it (a new backup
  version, fixtures); an older backup restores with no quests.
- **Proposed:** Pip's life isn't in Clear data (as now), so neither are
  his quests.

## 12. Later quests

- **Requested:** after the house, more quests, e.g. **Build a bed**: he
  looks for sheep (wool), wood, etc.; it brings new idling (jumping on
  the bed) and a new place to sleep.
- **Requested:** house-area events to be added later.

## 13. Open

- The drafts (`docs/pip_house_drafts.png`): the house at its stages, the
  materials, the fireplace, the porch, the scaffold, the rain hat, the lantern.

## 14. Order of work

1. This spec and the drafts, approved.
2. **Rules and data:** the script (steps, minutes, materials), work
   minutes from the clock (power downs, trips, windows, the clock going
   back), the inventory; `pip.json` v4, backup, fixtures; tests for each
   case.
3. **Pip Home:** the Quests button and card, Start in quest hours,
   completed quests' pictures, the inventory card and the swipe order.
4. **Scenes:** the house area, walking between places, gathering
   (forest, mine, beach), the fireplace, building with flying materials and
   smoke, the scaffold, the house drawn from the script's progress (the
   strip's view and Pip Home's).
5. **Weather, seasons, night and occasions** in the house area and out
   gathering; events held off in quest hours; no charging in quest
   hours.
6. **The finished house:** his idling area, sleeping inside, the
   station where he is, which events stay; the next quest offered (to
   be specced).
