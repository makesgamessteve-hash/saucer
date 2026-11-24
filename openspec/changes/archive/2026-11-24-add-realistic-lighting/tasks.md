## 1. Engine

- [x] 1.1 `engine/src/core/sx_light.{h,c}`: light list, selection, shadow budget presets, cube faces, shadow matrices
- [x] 1.2 `sx_render`/`sx_engine`/`sx_script`: per-viewport lighting, `--shadows`, `view:light`, `view:lighting`, `saucer.render.lights`, `settings{shadows=}`, mesh `owner`/`noshadow`
- [x] 1.3 `platform/sx_gl.c`: light loop, depth atlas (cascades, spots, cube faces), caster culling, cached omni maps, per-mesh light lists

## 2. Game

- [x] 2.1 `view/lights.lua`: stars, palettes, room lamps, bay and station lamps, Watcher spots, the saucer's lights
- [x] 2.2 `sim/lights.lua`: switches, keys and pad button; signature (`sentries.lua` `stealth.lights`); state version 18
- [x] 2.3 HUD lights label and help line

## 3. Tests and tools

- [x] 3.1 `tests/c/test_light.c`, `--shadows` option test
- [x] 3.2 `tests/lua/lights_spec.lua`, `tests/game/lighting.lua`
- [x] 3.3 Replays re-recorded; `tools/shots/lighting.{lua,sh}` and `lighting_perf.lua`
