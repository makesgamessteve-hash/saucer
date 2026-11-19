## 1. Slice 1: hull door and landing gear

- [x] 1.1 `saucer/landing.lua` tuning; `sim/landing.lua`: foot probe (ground, wall, void, slope), land/lift-off, gear animation, anchoring
- [x] 1.2 `sim/hulldoor.lua`: hull hatch state, airlock cycle in vacuum or toxic air, hysteresis and minimum open time, stairs geometry for the ground, walking the stairs
- [x] 1.3 `sim/env.lua`: where you are (vacuum, toxic, air) for the suit
- [x] 1.4 `sim/excursion.lua`: the standing Villa (`stand` coin), fold from outside, unfold with room checks, board by the stairs
- [x] 1.5 Input: `land`, `home`, `assist` buttons; state version 14
- [x] 1.6 View: legs, door leaves, belly plates, stairs (`view/gear.lua`); the hull gets a doorway (`gap` on lathe shells), the lower deck wall a frame
- [x] 1.7 Tests: `tests/game/hatch.lua` (+ restore every tick), `tests/lua/landing_spec.lua`, replays re-recorded

## 2. Slice 2: station tractor dock

- [x] 2.1 Tractor guide into the hangar bay, cancel by pulling away, dock pad with clamps
- [x] 2.2 Door and stairs onto the hangar floor; pocket and unpocket in the hangar with a clear-space prompt
- [x] 2.3 Tests: `tests/game/dock.lua` (+ restore every tick), `tests/lua/dock_spec.lua`

## 3. Slice 3: land anywhere

- [ ] 3.1 Landing mode HUD (ground distance, slope), landing on asteroids, moons, planets, rooftops, wrecks
- [ ] 3.2 Moving surfaces
- [ ] 3.3 Tests

## 4. Slice 4: EVA kit

- [ ] 4.1 Helmet overlay and HUD, oxygen and suit integrity
- [ ] 4.2 Jetpack, return assist
- [ ] 4.3 Emergency teleport and low-oxygen auto-teleport
- [ ] 4.4 WebXR wrist HUD, touch buttons
- [ ] 4.5 Tests
