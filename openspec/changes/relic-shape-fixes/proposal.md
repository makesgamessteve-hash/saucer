## Why

The spiral reel (Steve, t66u) turned up three problems with the relic stations, and Steve asked for all three to
be fixed:

1. **Two layouts never turn up.** A civ's relic layout comes from its social structure's `massing` list in
   `civs/traits.lua`, and those lists only handed out six of the eight layouts (ring, spine, cluster, hive, shell,
   helix). The organism spiral and the lattice diamond never appeared in a real world.
2. **Curved and angled halls had flat corners.** The solid that fills a box outside its shape was drawn as one
   bare slab per contour segment: flat purple panels with blade ends where segments meet, nothing like the ribbed
   cushion skin of the box walls.
3. **A grey speckled ceiling.** A civ whose fate is ascension has quartz as its decay material; the decay hall
   (plague hall) is skinned with it. Quartz sparkles, and over a whole hall the sparkle reads as grey static (the
   dominant crystal already gets a calmed look for the same reason; the decay slot did not).

## What Changes

- `civs/traits.lua`: hive social structures can also build the lattice (`hive`, `cluster`, `lattice`), gestalt
  social structures the organism (`shell`, `organism`). Over 120 worlds every one of the eight layouts now turns up.
- `view/relic.lua`: a shaped hall's wall is dressed like the box's own: chrome ribs, floor to ceiling, every
  `SHAPE_RIB` (5 m) along each run of the contour (`sim/relicshape.chains` joins the contour's segments into runs),
  and chrome bands at the rows the box cushions split into; slabs no longer run past their ends (no blades).
- `view/materials.lua`: the decay slot's crystal gets the calmed look (a third of the sparkle, toned ramp, rim and
  reflection) like a dominant crystal.
- State version 23 (civ rosters, so relic layouts, change for the same seed); seed-42 slice and co-op replays
  re-recorded.

## Impact

- Specs: `relic-stations` (ADDED: every layout turns up; a shaped wall is dressed; a decay crystal is calmed)
- Code: `data/base/civs/traits.lua`, `sim/relicshape.lua`, `sim/game.lua`, `view/relic.lua`, `view/materials.lua`
- Tests: `tests/lua/relicshape_spec.lua`, `tests/lua/relicunique_spec.lua`, `tests/lua/relicplay_spec.lua`,
  `tests/lua/civroster_spec.lua`, `tests/lua/funfixes_spec.lua`
