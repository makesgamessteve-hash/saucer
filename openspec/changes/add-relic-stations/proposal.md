## Why

PR #15's alien stations are living trader stations. The relic design (`design/civs-and-relics.md` §3, §5, §6)
adds dead ones: huge structures a vanished civilization left behind, flown through in the Villa, with Seat-sized
branches off them. This change is the first, Reel-ready slice (§9): one relic, built and played end to end.

## What Changes

- **Spine relic** (`sim/relicgen.lua`, kit `kits/relic.lua`): one straight spine, about 936 m from the maw to the
  Core's far wall: a 34 x 20 m maw, three 96 x 48 x 96 m hub halls joined by 40 x 24 x 160 m trunks, a
  128 x 64 x 128 m Core. The second hall breathes (render only), the third is plague-struck. It returns the usual
  ruin table (rooms, doors, walls, slots) plus `relic` (spaces, bays, branches, locks, Villa share, length) and
  validates: Villa-class doors all the way to the Core, class minimums, a bay within 30 m of every Seat port,
  the Charge plan, a Villa share of at least 75% (it is 91%). Collision is the ruin's boxes only.
- **Fold bays with cradles.** 44 x 20 x 44 m bays on the hall floors, one in the first and third hall and four
  in the port's hall (four co-op players), each with a dormant power cradle: growing from the Seat to the Villa
  in a cradle bay costs no Charge, and a resting Villa refills 1 Charge a second (half the open-space rate).
- **One Seat branch.** A 2.6 x 2.1 m port in the breathing hall's wall, an 80 m passage of 4 x 4 m with one
  elbow, and a 12 x 8 x 12 m reliquary holding three class-1 finds (paid double) behind a Seat-lock: nose the
  Seat up to its socket and hold Use for 1.5 s; the shutter stops being solid and stays open (saved in
  `state.relic_locks`). The HUD shows a green or red ghost Villa wherever a Seat is in a Villa-class space.
- **Loot.** Six finds over the halls (classes 2-3) and an XL idol in the Core (class 4, a fixed find only the
  Villa's beam lifts). No sentries.
- **Skins** (`view/relic.lua`): membrane cushions dished between chrome ribs on the walls and ceilings (the
  outside a swollen hide), PIERCE chrome spines through the membrane each ringed by a wound, chrome door frames
  with wound rims, a membrane lip and chrome teeth round the maw, chitin floors, amethyst clusters in the Core
  and reliquary, cradles, the idol. Every skin sits on or outside a wall's inner face. Lamps in the Vyrr's
  colours (`view/lights.lua` takes them from `view/relic.lua`).
- **Debug entry.** `--relic-slice` adds the Vyrr relic to the first sector (4 km below its plane) and starts the
  party 90 m outside the maw. Without it nothing changes: no state version bump, replays unchanged.
- **Shots.** `tools/shots/relic_slice.lua`: the screenshot tour, and with `--script-arg frames` a 9:16 Reel
  fly-through as numbered frames.

## Impact

- Specs: `relic-stations` (new), `saucer-configurations` (MODIFIED: grow requires clearance, free in a cradle bay)
- Code (phase 8): `sim/sector.lua`, `sim/relicsentry.lua`, `sim/relicloot.lua`, `sim/save.lua`, `view/relicdecay.lua`,
  `view/relicmap.lua`
- Code: `sim/relicgen.lua`, `sim/relic.lua`, `kits/relic.lua`, `sim/ruin.lua`, `sim/game.lua`, `sim/ship.lua`,
  `sim/tractor.lua`, `sim/sentry.lua`, `view/relic.lua`, `view/render.lua`, `view/lights.lua`
- Out of the slice: other archetypes, generated rosters, relics in far sectors, sentries, foot pockets.

## Plan phase 8: relics in normal play

- **Placement** (`sim/sector.lua`): a relic site in the third sector of every universe and in about a third of
  the farther ones (never home or the Heart's), its build box 120 m clear of every other site, the city and the
  station; appended last on its own seed child, so nothing else in a sector moves.
- **Sentries** (`sim/relicsentry.lua`): Watchers in every third hall, Snatchers nesting in the Seat chambers of the
  longest branches, Spotters drifting round the busiest junctions; the maw's hall and the heart stay calm.
- **Loot** (`sim/relicloot.lua`): two finds in every hall, one at most in a chamber, chamber finds thinned until the
  warrens hold 25-40% of the value (they held 70-85%).
- **Memory** (state v20): explored rooms, the approach scan and the heart, and the Seat-locks, all saved; the scan
  names the relic once at 2.5 km; the radar map draws the remembered rooms.
- **Decay** (`view/relicdecay.lua`): dead lamps and fallen heaps by the civ's fate and era, render only.
- Not yet: design keys as cosmetic unlocks, the hall pulse with port pips (flagged for a later phase).
