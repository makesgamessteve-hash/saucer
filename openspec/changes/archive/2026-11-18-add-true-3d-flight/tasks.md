## 1. Flight

- [x] 1.1 Six-axis flight with look-coupled thrust, lift, strafe, dampening and a hover that holds altitude (`sim/flight.lua`); specs in `tests/lua/flight_spec.lua`
- [x] 1.2 Visual bank capped at BANK_MAX, with the interior and eye locked to the saucer frame; no bank in XR or during a fold (`view/render.lua`)
- [x] 1.3 Inputs: keyboard and mouse, gamepad, touch up/dn hold buttons (`sx_touch.c`, C tests) and WebXR
- [x] 1.4 Camera roll and mesh pitch/roll in the engine (`sx_render.c`, `sx_script.c`, `tests/c/test_phys3d.c`)

## 2. World

- [x] 2.1 Six-direction generator with hatches, shafts, a minimum span and number of levels, solids and a 3-level fallback; memoized (`sim/ruin.lua`); specs and layout known answers in `ruin_spec.lua`
- [x] 2.2 Kits: starship, station and a new city kit, all huge
- [x] 2.3 The sector places sites at different heights
- [x] 2.4 Uniform-grid physics broadphase, equal to brute force (`sx_phys.c`, `test_phys3d.c`)
- [x] 2.5 Sentries in 3D: hatch and shaft Watchers, pitch-aware line of sight and cones, vertical Snatcher patrols
- [x] 2.6 3D radar, altitude tape, elevation cue, nearest site by bounds
- [x] 2.7 Render chunks, culling, LOD and fog; exterior lights

## 3. Verification

- [x] 3.1 Game tests `vertical.lua` and `derelict3d.lua` (seeds 42 and 7); the existing game tests still pass
- [x] 3.2 Sim version 5 and save format 2; `slice_seed42.srep` re-recorded
- [x] 3.3 Coverage of at least 95 % (C and Lua)
- [x] 3.4 Screenshot tour `tools/shots/true3d.lua`
- [x] 3.5 Docs: `docs/concept.md` v0.6, `docs/ROADMAP.md`, README controls
- [x] 3.6 CI green on linux-gcc, linux-clang, windows-msvc, emscripten and lint; Pages deployed
