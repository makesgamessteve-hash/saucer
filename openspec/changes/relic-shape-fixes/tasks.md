## 1. Layouts
- [x] 1.1 `civs/traits.lua`: lattice under hive, organism under gestalt
- [x] 1.2 `tests/lua/civroster_spec.lua`, `tests/lua/relicunique_spec.lua`: all eight layouts over many seeds; relics of each build

## 2. Shaped walls
- [x] 2.1 `sim/relicshape.lua` `chains`: the contour joined into runs
- [x] 2.2 `view/relic.lua` `dress_walls`: ribs along each run, bands at the cushion rows; slabs without blade ends
- [x] 2.3 `tests/lua/relicshape_spec.lua`: chains, ribs and bands on the free side, spacing, no blades

## 3. Decay crystal
- [x] 3.1 `view/materials.lua`: the decay slot's crystal calmed like a dominant crystal
- [x] 3.2 `tests/lua/relicplay_spec.lua`: quartz decay calmed; organic and sparkle-less crystals untouched

## 4. Verification
- [x] 4.1 State version 23; seed-42 slice and co-op replays re-recorded
- [x] 4.2 Uniqueness: 300 chained stations per species, every pair at least `MIN_DIST` apart
