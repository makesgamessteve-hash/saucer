## 1. Rule and simulation

- [x] 1.1 Beam parameters per configuration with defaults for old mods (`saucer/configs.lua`, `tractor.beam`)
- [x] 1.2 Capture rule: class, depth, cone, keel for long scrap, level, still, line of sight, with hints (`tractor.check`, `tractor.scan`)
- [x] 1.3 Long scrap gets a deterministic axis from its instance seed
- [x] 1.4 Pull over time up the beam axis with shrinking (`tractor.pull_time`, `tractor.pull_pose`)
- [x] 1.5 The lock drops on getting up, folding, the target going or the saucer drifting away
- [x] 1.6 Console trim in the operator's frame (`flight.trim`); hover-hold while walking

## 2. Tractor Room

- [x] 2.1 Third deck, belly stair, nav nodes and the console station (`saucer/interior.lua`, `sim/avatar.lua`)
- [x] 2.2 Room meshes: floor window, hatch rim, sling seat, console arms, cargo tube, hold racks, walls, lights
- [x] 2.3 Console view looking down through the glass; Use sits down / gets up
- [x] 2.4 The Seat's mini beam fires from the seat

## 3. Presentation

- [x] 3.1 Beam cone, core and motes; target ring, item axis and keel line; hatch iris and glass (`view/render.lua`)
- [x] 3.2 Console scope, pull bar and lit hold cubbies
- [x] 3.3 HUD alignment indicator, hints and status lines; README controls
- [x] 3.4 Emitter ring and lenses on the Villa's belly

## 4. Verification

- [x] 4.1 Unit specs: rule order, hints, frame, pull pose, console, HUD and render (`tests/lua`)
- [x] 4.2 `tests/game/tractor.lua`: helm refusal, walk down, keel refusal, trim, pull and shrink, getting up drops it, off-axis refusal, Seat mini beam
- [x] 4.3 Game tests use the beam drivers; replay known answers re-recorded
- [x] 4.4 Coverage at least 95% for C and Lua
- [x] 4.5 Screenshot tour `tools/shots/tractor.lua`
