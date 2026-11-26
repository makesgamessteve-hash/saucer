## 1. Shapes
- [x] 1.1 `sim/relicshape.lua`: shape kinds, per-relic style, door channels and clear centre, fill, contour, settle
- [x] 1.2 `sim/relicgen.lua`: assign shapes to patterned relics' halls (not the maw's hall, lung, plague hall or heart); settle slots and phenomena; `ruin.fill`
- [x] 1.3 `sim/game.lua`: the fill goes into physics
- [x] 1.4 `view/relic.lua`: contour walls and seams; hall lamps over free floor
- [x] 1.5 `view/relicmap.lua`, `tools/maps/`: maps follow the shape
- [x] 1.6 `sim/relicloot.lua`, `sim/relicsentry.lua`, `sim/stealth.lua`: finds, sentries, cover over free floor

## 2. Uniqueness
- [x] 2.1 `sim/relicpat.lua`: per-relic pattern variant
- [x] 2.2 `sim/relicsig.lua`: signature and distance
- [x] 2.3 `sim/sector.lua` siblings, `sim/relicgen.lua` generate/unlike: a relic unlike its species' earlier relics
- [x] 2.4 `tools/relicunique/`: a few hundred stations per species, distances in bulk

## 3. Verification
- [x] 3.1 `tests/lua/relicshape_spec.lua`: kinds, channels, fill, settle, assignment, shell vs ring, autopilot ways, loot, phenomena, sentries, cover, lamps, walls, map, collision
- [x] 3.2 `tests/lua/relicunique_spec.lua`: metric, redraw, every relic in play of many universes, a run of stations per species
- [x] 3.3 State version 22; seed-42 slice and co-op replays re-recorded
