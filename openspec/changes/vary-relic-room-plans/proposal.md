## Why

Steve said that on the room plans, the relic space stations all look like rectangles, and asked for more
interesting patterns like the alien-station archetypes: spirals, something more like a sphere, and recursive
patterns. The Phase 6 massing grammars only changed the size of a rectangular lattice (a "ring" was a hollow
square), so every relic still read as a box of halls with the heart stuck on the end.

## What Changes

- **Room-plan patterns** (`sim/relicpat.lua`, `civs/dungeons.lua`): each massing archetype now places halls in
  its own overall shape, with the heart in a reserved centre, instead of filling a rectangular lattice:
  - organism: a 4-connected spiral gullet into the heart, with short organ branches
  - lattice: a diamond / octahedral ring around the heart
  - shell: spherical shells (a large equatorial ring, smaller rings toward the poles)
  - ring: a 4-connected square ring around the heart, with stacked cardinal spokes
  - helix: a climb around the heart that reads as a spiral from above
  - hive: a Sierpinski right-triangle gasket, the heart in the largest removed square
  - cluster: a recursive H-tree around the heart
  - spine: a slightly bent axis with recursive side wings, the heart in the middle
- Patterns vary with the relic seed (handedness, depth, which arm is the start) as well as the civ.
- Heart halls, locks, crawlspaces, sentries, loot, fold bays, Charge plans and navigation keep their existing
  gates. Styled relics still take up to 16 tries.
- **The slice is unchanged**: the Vyrr pin `layout = "warren"`, so the kit's rectangular lattice, its goldens
  and the slice replay stay the same.
- State version 21, because non-Vyrr relic layouts (and so remembered room ids) change for the same seed.
- `tools/maps/` keeps dumping a top-down map of every archetype.

## Impact

- Specs: `relic-stations` (ADDED: relic room-plan patterns)
- Code: `civs/dungeons.lua`, `sim/relicpat.lua`, `sim/relicgen.lua`, `sim/game.lua`; tests
  `tests/lua/civdungeon_spec.lua`
- Replays that include the state version need a re-record if they hash the version.
