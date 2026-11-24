## 1. Engine

- [x] 1.1 `sx_light.{h,c}`: per-light `haze`, haze budget per preset and view count, glowing-light selection
- [x] 1.2 `sx_script.c`: `view:light{haze=}`, `view:lighting{haze=}`, `saucer.render.lights` haze fields
- [x] 1.3 `sx_gl.c`: in-scattering in the mesh shader (point halo closed form, spot cone samples), skybox rays

## 2. Game

- [x] 2.1 `view/lights.lua`: dark pools per room, dark rooms, city pools, global lamp dimmer and haze funnel
- [x] 2.2 Haze for headlights, floods, Watcher spots and placed lamps

## 3. Tests and tools

- [x] 3.1 `tests/c/test_light.c` haze budget and selection
- [x] 3.2 `tests/lua/lights_spec.lua` pools, dark rooms, dimmer, haze; `tests/game/lighting.lua` haze per preset
- [x] 3.3 `tools/shots/lighting.lua` ruin staging for the beam shots; desktop and web frame-time check
