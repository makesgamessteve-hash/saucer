## 1. Renderer forms

- [x] 1.1 Add `form` to `view:billboard` and procedural shader forms (disk, flare, spark, ring, shard, streak, chevron, slit)
- [x] 1.2 C test that a billboard stores its form

## 2. A form for each use

- [x] 2.1 `view/sprites.lua` helpers (light, spark, ring, shard, streak, mark, slit, pool, shade, ripple, bolt)
- [x] 2.2 Route every former glow/loot/echo/beam bubble to the form that fits it

## 3. Specs and shots

- [x] 3.1 `tests/lua/sprites_spec.lua` covers the forms and the main call-site routing
- [ ] 3.2 HUD-off before/after shots of each use
- [ ] 3.3 Local gate (>= 95% coverage) and merge
