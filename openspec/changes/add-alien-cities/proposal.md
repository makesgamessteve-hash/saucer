## Why

Plan phase 10 (design `civs-and-relics.md` §4). Today's cities are grids of box towers in one of four old shapes, and their
ordinary districts are just "market", "residential" and "industrial". Steve wants stations and alien cities to be
interesting to explore, with strange things going on that are visible, sometimes moving, never dangerous, and not
understood. This change is the first part of phase 10: cities shaped by the civ that built them, plus city-scale
phenomena. The megascale core, lazy district generation, LOD and mini-relic organs come in later parts of this change.

## What Changes

- **Towers in the civ's massing.** A roster civ's towers take its massing's form (`citygen.MASSING_FORMS`):
  ring → crater crown, spine → ribbed spine, cluster → pods, hive → stacked cells, shell → terraces,
  lattice → pillars under a lintel, helix → boxes winding round a core, organism → swollen lobes.
  - The old shape-based forms stay for civs without a massing.
  - Every form is boxes inside the tower's footprint (`citygen.FORMS`), and its first tier is the full footprint, so
    collision equals the drawing and sky-bridges still land.
- **Districts by value** (§4.3). Each ordinary district stands for a value: the builders' own for 60% of them, another
  value for the rest. Each value has its own label and tower form:
  - knowledge → Archive Spires
  - hoarding → Treasury Vaults
  - faith → Cathedral Organs
  - kinship → Brood Warrens
  - conquest → Fortress Terraces
  - craft → Foundry Trenches
  - harmony → Choir Bowls

  Every other tower in such a district takes its value's form. The values are drawn from their own rng, so rooms,
  doors, slots and landmarks are exactly as before. Landmarks keep their kinds and labels.
- **Sky lanes.** `city.lanes` runs one lane between every pair of neighbouring districts, high over the towers.
- **City phenomena** (`view/cityphen.lua`, render only, a function of the clock and the eye):
  - Swarms of motes wheel over every district's avenue and part round the saucer.
  - A ring and two arms cycle on each district's tallest tower.
  - Light pulses run down the sky lanes.
  - None of them collide or touch the state.
- No state version bump. Cities' rooms, doors and slots are unchanged; only the tower boxes change shape. Replays are
  unchanged.

## Impact

- Specs: `cities` (MODIFIED: City silhouette and light colour; ADDED: District values, Sky lanes, City phenomena)
- Code: `sim/citygen.lua`, `view/cityphen.lua` (new), `view/render.lua`
- Tests: `tests/lua/aliencity_spec.lua`; shots `tools/shots/alien_city.lua`
- Later in this change: a 12-20 km core of 24-48 districts generated lazily in time slices, the active set, LOD levels
  and the horizon band, strata and the undercity, mini-relic organs and the state version bump (design §4.2-§4.4)
