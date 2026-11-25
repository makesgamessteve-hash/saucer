## 1. Generation
- [x] 1.1 `sim/relicfoot.lua`: pockets by body scale off Seat chambers (crawlspace, pocket room, channel, route)
- [x] 1.2 The lock mix: the hand-lock's chamber (at most 15% of the value), 1-2 chamber Seat-locks, nests never sealed
- [x] 1.3 Derived once per generated relic, on a copy (`relicfoot.derive` in `game.rebuild`)

## 2. Play
- [x] 2.1 Excursion areas from `ruin.foot.areas`; POCKET on the HUD
- [x] 2.2 Lore niches: reach, Use reads the glyphs
- [x] 2.3 Lock messages for sealed chambers

## 3. Look
- [x] 3.1 Crawlspace mouth frames per pocket, niche glows

## 4. Verification
- [x] 4.1 `tests/lua/relicfoot_spec.lua`
- [x] 4.2 `tests/game/relic_locks.lua` (CTest `game_relic_locks`, `game_relic_locks_seed7`; in the coverage runs)
- [x] 4.3 Replays unchanged (no state version bump)
- [x] 4.4 Screenshots: ledge, crawlspace, the hand-lock pocket and the opened chamber
