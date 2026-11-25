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

## Part 2: megascale

- **The megacity** (`sim/citymega.lua`, §4.2). The core stays the downtown; a ring of outer districts fills a ~21 km
  footprint, 24-48 districts in all. Each is a block of civ-shaped megaforms (180 m to 1.5 km, one city megaform 2-2.8 km)
  between canyon avenues, on a foundation that floors the avenues, with strata decks between neighbours.
- **Streaming** (§4.4). Only districts within 1.5 km of a ship are solid (9 per player, 16 in all), built synchronously
  when needed; the view builds ahead within a 6 ms frame budget (4 ms on the web). Nothing is saved: the plan and the
  districts are pure functions of the seed, and a restore re-derives the solid set from the players' positions.
  The physics list drops removed boxes at its tail, so streaming does not grow it.
- **Detail levels.** Full meshes with lit windows within 4 km, lit silhouettes to 40 km, a horizon band at 26-50 km.
  Over a megacity the far plane is 60 km, the city's air holds over the footprint, and backdrop sprites (nebulae,
  planet, star) are drawn with the sky so far towers stand in front of them. The planet city's haze is thinner (1.6 → 1.0).
- Per-district diffs and the state version bump move to part 3, when the outer districts get loot and doors.

## Part 3: organs and drifters

- **Organs.** Each outer district's tallest ordinary megaform is hollow at the street: a hall behind a mouth facing the
  avenue, with 4-6 finds and a slowly turning ring. Its finds are ordinary per-player finds (`looted` keys), so no new
  state and no version bump.
- **Drifters.** Glowing slabs glide down the outer avenues, turning and bobbing: harmless, render only.
- Relicgen interiors, fold bays, the undercity warrens and the remaining add-cities extras stay for a later part.

## Part 4
- The organ's machine fills its hall; drifters are bigger and carry halos and followers.
- Fold bays with cradles on the terraces: growing back to the Villa there is free.
- The undercity: a shaft from each organ hall into a warren of corridors and chambers ending in a breathing sanctum,
  with deep finds. No new state: taken finds are `looted` keys, so no version bump and replays unchanged.
- Transit and storm extras, mystery tie-ins and full relicgen interiors stay for later.

## Part 5
- The warren is lit; hall finds keep off the shaft; districts build in about a fifth of the time and ahead of need.
- Mag-trains over the outer avenues, the storm over the ring, an archive record in each sanctum. No new state: the
  record is a `looted` key, the wind a function of the tick. Full relicgen interiors stay for later.

## Part 6
- Rails and pylons under the mag-trains, solid as drawn; drifters moved off the midline.
- The warrens carry the builders' relic phenomena. A full relicgen layout under each organ is out of scope: it would
  need each organ to be a site of its own.
