## Why

The relic design (`design/civs-and-relics.md` §2.3) wants alien places to read through their materials: chrome
that reflects, crystal that glows and refracts, membrane that breathes. Until now every mesh was one flat-lit
vertex colour on an indexed texture.

## What Changes

- **Material slot per vertex.** Mesh vertices carry a 13th float, the material slot 0-7, set from the part style
  (`mat = n`). Slot 0 is plain and takes the old shading path bit for bit. Mesh hashes of meshes without
  materials are unchanged.
- **Per-view slots.** `view:materials{ time, matcap, slots = { [1..7] = {...} } }` sets eight slots per view:
  kind (plain, metal, crystal, organic) and its parameters, packed into one uniform array (`sx_material.c`).
- **Matcap.** `saucer.render.matcap(name, lights, ambient)` bakes a 64 x 64 banded luminance matcap from up to four
  lights (no libm), kept under its name.
- **Shading** (`sx_gl.c`): metals reflect the matcap through a palette ramp in 8 bands plus Blinn specular and a
  fresnel term; crystals look through it (fake refraction), with facets, glow, pulse and a rim; organics get
  wrap lighting, a subsurface tint, wobble and breathing along the normal and a vein pulse. One matcap fetch per
  pixel. Wobble, breathing and pulses use render time only.
- **Setting.** `--materials off|lite|full` and `saucer.render.settings{ materials = ... }`: full on desktop, lite
  on the web (no refraction, no wobble, half breathing), off renders today's look.
- **Library.** `data/base/civs/materials.lua`: 26 records (metals, crystals, organics, stone, enamel) with a ramp and
  kind parameters; `view/materials.lua` turns a civ's material table into the slots.
- **Golden shots and budget.** `tools/shots/materials.lua` + `materials.sh` + `golden_compare.py` (goldens in
  `tests/golden/`), `tools/shots/relic_perf.sh` for the frame budget.

## Impact

- Specs: `materials` (new), `retro-renderer` (ADDED: material shading, budgets, setting), `mesh-builder`
  (ADDED: material slot per vertex, the patch primitive)
- Code: `engine/src/core/sx_material.[ch]`, `sx_mesh.[ch]`, `sx_render.[ch]`, `sx_script.c`, `sx_engine.[ch]`,
  `engine/src/platform/sx_gl.c`, `data/base/civs/materials.lua`, `view/materials.lua`
- No state or replay changes: every replay also plays with `--materials off` (CTest `replay_*_materials_off`).
