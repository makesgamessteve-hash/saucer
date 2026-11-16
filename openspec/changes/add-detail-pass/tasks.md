## 1. Saucer

- [x] 1.1 Decor props per room, visual only (`saucer/decor.lua`, `meshes/props.lua`)
- [x] 1.2 Railings, stair rails, dome frame, floor trim and ceiling ribs (`meshes/interior.lua`)
- [x] 1.3 Engine machinery with animated rotors and pistons (`view/render.lua`)
- [x] 1.4 Hull seams, lights, antennas, thrusters and glow; the Seat's fins (`meshes/saucer.lua`)
- [x] 1.5 Saucer LOD: far saucers skip their rooms

## 2. Alien structures

- [x] 2.1 Room detail generator with per-kit styles and budgets (`view/detail.lua`)
- [x] 2.2 Exterior solid detail: towers, trusses and spines; city sky bridges
- [x] 2.3 Per-kit textures through artpipe, prompts logged
- [x] 2.4 Lazy per-chunk detail meshes, build cap, distance and view culling (`view/assets.lua`, `view/render.lua`)

## 3. Verification

- [x] 3.1 `tests/lua/detail_spec.lua`: determinism, budgets, bounds, keep-outs, no ruin mutation, render cap, kit textures
- [x] 3.2 Sim hashes and replays unchanged; coverage at least 95% for C and Lua
- [x] 3.3 Screenshot tour `tools/shots/detail.lua`
