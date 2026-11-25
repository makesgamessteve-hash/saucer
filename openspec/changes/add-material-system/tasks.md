## 1. Engine
- [x] 1.1 13-float vertex with the material slot; part style `mat`; mesh hash unchanged without materials
- [x] 1.2 `sx_material.c`: slots, kinds, modes, packing (off/lite/full), matcap baker, wobble bound
- [x] 1.3 `view:materials`, `saucer.render.matcap`, the `materials` setting, `--materials`
- [x] 1.4 GLSL: metal (matcap through the ramp, Blinn, fresnel), crystal (refraction, glow, rim), organic (wrap,
      subsurface, wobble, breathing, vein pulse); slot 0 is the old path

## 2. Data
- [x] 2.1 `civs/materials.lua` library; `view/materials.lua` civ slots, materials-off colours, matcap

## 3. Verification
- [x] 3.1 C: `material_slot_round_trip`, `material_pack_modes`, `matcap_bake`, `material_wobble_bound`,
      `mesh_hash_material`, `materials_relic_options`
- [x] 3.2 Lua: `tests/lua/materials_spec.lua`
- [x] 3.3 Render-only: `tests/game/relic.lua` (full, lite, off end in one state); `replay_*_materials_off`
- [x] 3.4 Golden shots: `tools/shots/materials.sh` (relic scene full/off; legacy scene off is pixel-identical to
      main 2d5d372)
- [x] 3.5 Budget: `tools/shots/relic_perf.sh` (full/off p95 ratio)

## 4. Polish (plan phase 1)
- [x] 4.1 Stronger full look: chrome glints and rim in dim light, brighter crystal glow, deeper subsurface and veins
      (veins stay dark where the pulse is off: plague halls)
- [x] 4.2 Goldens re-rendered; `golden_compare.py --differ`: full differs from off by at least 9.5 (was 7.4 / 8.1)
- [x] 4.3 CI job `golden`: builds the game, runs `tools/shots/materials.sh` under Xvfb (legacy tolerance via
      `LEGACY_TOL` for another Mesa), uploads the shots

## 5. The rest (plan phase 7)
- [x] 5.1 Fate materials (design §2.3.4): war scorch, ascension crust, sleep dormancy, flight stripping, schism split
      (`view/materials.lua` `fate`; plague keeps its decay slot)
- [x] 5.2 Crystal sparkle, brushed-metal stretch and liquid-metal ripple (a sixth vec4 per slot; lite drops the
      sparkle and halves the ripple; the slice's amethyst and chrome keep their look, goldens unchanged);
      `tools/shots/material_sheet.lua`
- [x] 5.3 A 128 x 64 sector-sky reflection map for exteriors (`sx_skymap_bake`, `saucer.render.skymap`, `u_envmap`:
      metals and crystals outside a relic look up the sky by world direction, still one fetch; inside: the matcap)
- [x] 5.4 Headset comfort (`view/materials.lua` `xr_slots`): sparkle off, wobble halved, breathing no faster than 4 s
      (whole view: a relic's interior is always within 120 m of the eye)
