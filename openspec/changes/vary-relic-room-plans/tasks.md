## 1. Patterns
- [x] 1.1 `civs/dungeons.lua`: each massing archetype names a `pattern` (spiral, diamond, shells, rings, helix, sierpinski, htree, spine); the Vyrr stay on the warren
- [x] 1.2 `sim/relicpat.lua`: hall-centre plans for those patterns, the heart in the reserved centre, seed variation
- [x] 1.3 `sim/relicgen.lua`: `layout_pattern` joins the plan with trunks, L-corridors and shafts; keep heart, maw, locks, chambers, sentries, loot and navigation
- [x] 1.4 State version 21

## 2. Verification
- [x] 2.1 `tests/lua/civdungeon_spec.lua`: the Vyrr warren hash is unchanged, every pattern is valid with the heart on the main way and inside the halls' footprint, rings are not a filled rectangle, body scale, determinism, seed variation
- [x] 2.2 `tools/maps/`: top-down maps of every archetype, before and after
- [x] 2.3 Seed-42 slice and co-op replays re-recorded for state version 21
