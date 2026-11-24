## Why

Steve asked for entering and leaving the saucer to be a real thing, not a teleport: a door that
opens and closes, stairs that unfold, a tractor dock inside a space station, folding the saucer
into the pocket from outside, landing on any surface to explore on foot, and, outside in space, a
helmet, a HUD, a jetpack and an emergency teleport home.

## What Changes

Four slices, each merged on its own:

1. **Hull door and stairs (landing gear).** The Villa lands on three telescoping legs
   (`sim/landing.lua`: a probe under the feet checks ground and slope, a gear animation, anchoring to the
   surface). A hull hatch (`sim/hulldoor.lua`) aft of the engine room opens only when landed (and in
   vacuum or toxic air only once the suit has sealed), slides its leaves, and unfolds stairs to the
   ground; you walk out and back in first person. Outside you can fold the Villa into your hand and
   pocket it, and unfold it again where there is room. The Villa can no longer be pocketed from
   aboard in a derelict.
2. **Station tractor dock.** The station's beam takes the saucer over on approach and lowers it onto a
   hangar dock pad with clamps; the hatch and stairs open onto the hangar floor.
3. **Land anywhere.** A landing mode with a ground readout and slope check on asteroids, moons,
   planets, rooftops and wreck hulls; anchored to moving surfaces.
4. **EVA kit.** Fishbowl helmet, helmet HUD, jetpack, return assist, emergency teleport to the saucer.

State version 13; replays re-recorded after each slice.

## Impact

- ADDED capability `landing` (this change's `specs/landing`).
- Code: `sim/landing.lua`, `sim/hulldoor.lua`, `sim/env.lua`, `sim/excursion.lua`, `sim/game.lua`,
  `view/gear.lua`, `meshes/interior.lua`, `meshes/saucer.lua`, `engine/src/core/sx_mesh.c` (a doorway
  arc for lathe shells).
