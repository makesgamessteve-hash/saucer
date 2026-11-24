## 1. Generation
- [x] 1.1 `sim/relicgen.lua`: the spine (maw, halls, trunks, Core), the Seat branch, bays, slots, locks
- [x] 1.2 Validation: Villa-class route, class minimums, bay at the port, Charge plan, Villa share; 8 tries
- [x] 1.3 `ruin.generate` dispatches a relic kit; sentries skip relics

## 2. Play
- [x] 2.1 Cradle bays: free regrow (`ship.request(..., free)`), 1 Charge/s for a resting Villa
- [x] 2.2 Seat-lock: hold Use at the socket; the shutter's box goes; open across saves and restores
- [x] 2.3 XL idol (fixed find); reliquary finds pay double; ghost Villa for a Seat in a Villa space
- [x] 2.4 `--relic-slice` debug entry

## 3. Look
- [x] 3.1 `view/relic.lua`: cushions, ribs, PIERCE spines and wounds, frames, maw, floors, crystals, cradles, idol
- [x] 3.2 Lamps in the civ's colours; materials on the view

## 4. Verification
- [x] 4.1 `tests/lua/relic_spec.lua`
- [x] 4.2 `tests/game/relic.lua` (CTest `game_relic`, `game_relic_seed7`; in the coverage runs)
- [x] 4.3 `tools/shots/relic_slice.lua` tour and Reel frames
