## 1. Hull
- [x] 1.1 Families (coral, crystal, spiral, shells) in `sim/stationhull.lua` with shared frame/envelope
- [x] 1.2 Alien pods, monoliths, cocoons, conduits, glyph alphabet, palettes, pulsing beacons
- [x] 1.3 About twice the old size; triangle budgets; levels of detail
- [x] 1.4 Box-based sector placement near the start with a clear way in

## 2. Inside
- [x] 2.1 Alien wing generator (passages, doglegs, chambers of five looks), own rng stream
- [x] 2.2 Organic walls, ribs, chamber props and solids in `view/station.lua`
- [x] 2.3 Family lamp colours and shaft lamps in `view/lights.lua`
- [x] 2.4 Walk-in seed per sector; concourse nav stops from concourse doors only

## 3. Verification
- [x] 3.1 Unit specs: families, extent, determinism, placement, wing reachability
- [x] 3.2 Game test `tests/game/alien.lua`: dock at an alien station, walk the wing
- [x] 3.3 Shots before/after, generation and frame-time numbers
- [x] 3.4 State version 19; slice and co-op replays re-recorded
