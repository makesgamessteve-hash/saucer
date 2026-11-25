# Fix the station hull: the spinning layer collides

## Why
The trader stations' spinning layer (the Reef's spore halo, the Lattice's splinter halo, the Helix's helices and the
Gyre's nested shells) had no collision: a saucer flew straight through it.

## What Changes
- The station generator records collision shapes for the spinning layer in its own frame, in the layout pass too:
  spheres (spores, nodes), capsules (helix limbs, splinters, plates), annuli about the axis (seed rings) and tori
  (the Gyre's shells).
- Flight pushes the hull out of them where the layer stands at this tick: the turn comes from the sim tick, the same
  as the view's, so peers and replays agree.

## Impact
- Specs: alien-stations (ADDED: spinning layer collision)
- Code: sim/stationhull.lua (spin shapes, `spin_push`), sim/game.lua (the flight mover)
- Replays unchanged (neither path touches a spinning layer); no state version bump.
