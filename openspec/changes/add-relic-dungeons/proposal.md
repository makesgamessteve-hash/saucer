## Why

Steve: a relic of three halls is too small. Exploring a dungeon means a lot of rooms -- corridors, big halls and
small ones, ways round and dead ends -- and at the centre something magnificent, a gigantic engine hall, that
causes awe. More important still: the station must be interesting to explore, with strange things going on that
the player sees, maybe moving, never dangerous, never explained. This is plan phase 1b: the early, Vyrr-only
dungeon (civ-specific grammars follow in phase 6).

## What Changes

- **Warren archetype** (`sim/relicgen.lua`, `kits/relic.lua` `dungeon`): halls of 56, 72 and 96 m on a lattice of
  3 x 4 nodes on 4 levels (pitch 160 m, 72 m between floors), 22-28 of the 48 nodes filled. The way from the maw
  (top level, first row) to the lowest level's last row is carved first, the rest grows off it; trunk corridors
  (40 x 24 m) join neighbours on a level, shafts (40 x 40 m, floor and ceiling doors) join a node to the one above,
  and about a third of the remaining neighbour pairs get a second way (loops). Dead-end halls occur naturally.
  40-80 Villa spaces in all (validated).
- **The heart** (480 x 160 x 480 m) lies past the last row on the lowest level and opens only to it, so the shortest
  route from the maw crosses 1.1-1.7 km and 16-22 spaces (the autopilot's tree route takes about 4-4.5 minutes of
  straight flight; with dead ends, Seat branches and finds, 12-20 minutes of exploring). In its middle the engine:
  a solid column (80 m square, floor to ceiling) drawn as a chrome spindle with wound rings and an amethyst heart,
  roots over the floor, and three gyroscope hoops turning about it (render-only, from the clock). The XL idol
  stands before it.
- **Seat branches everywhere.** Besides the lung's locked reliquary (unchanged), every hall tries a branch through
  a door-less side: a 2.6 x 2.1 m port, a passage (4-13 cells, sometimes an elbow), a 12 x 8 x 12 m chamber and
  sometimes a second passage and chamber beyond it, keeping 24 m from every big space's hide. Each port has its own
  fold bay with a cradle by it (marker within 30 m). 15-30 Seat chambers (validated), one or two class-1 finds each.
- **Phenomena** (`view/phenomena.lua`): strange, harmless, render-only sights placed by the generator in 70% of
  halls, 40% of trunks and shafts and four in the heart, kinds drawn from the civ's own list
  (`language.phenomena`; the Vyrr: spores, breathing sacs and watching eyes most): rising motes, orbiting shards,
  an eye that turns to watch the saucer and dims up close, lights processing along a ceiling, a breathing sac,
  floor ripples, a shadow at a hall's end gone when you come near, swaying crystal chimes. They move with the clock
  and the eye only; nothing in the state sees them.
- **Skins for any room shape** (`view/relic.lua`): ribs across a room's long axis (x or z), cushions on every side
  without a Villa door and on the ceiling, giving way to Seat ports and shafts (flat wall there, with frames),
  frames on every door including floor and ceiling hatches, shoulders of hide round every neighbour, lobes that
  skip ports and roofs round a shaft. The heart's cushions and lobes grow with it.
- **Area culling and lazy meshes.** Room meshes are built when the eye comes within 3 doors of them (at most 4 a
  frame, nearest first) and freed beyond; inside the relic only rooms within 2 doors draw (Seat spaces only next
  door; from inside the heart, every trunk into it); outside it, rooms within 300 m draw in full and the rest as
  plain hull boxes. What draws from any room stays under the web's 180k triangles (worst about 127k).
- **Generation** takes about 0.01-0.1 s; up to 8 tries (about 78% of tries validate).
- Debug entry unchanged (`--relic-slice`); no state version bump, replays unchanged.

## Impact

- Affected specs: relic-stations (add-relic-stations' slice requirements generalised to the warren).
- Affected code: `sim/relicgen.lua`, `kits/relic.lua`, `civs/relic_slice.lua`, `view/relic.lua`,
  `view/phenomena.lua` (new), `tests/lua/relic_spec.lua`, `tests/game/relic.lua`, `tools/shots/relic_slice.lua`.
