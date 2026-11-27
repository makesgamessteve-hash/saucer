## 1. Body
- [x] 1.1 `sim/planet.lua`: seeded sphere, tangent street, flattened rim, height/kind/colour, sector-heart bay
- [x] 1.2 Landing and hull clamp on the surface outside the rim; crust below the warren; no collision in the heart bay
- [x] 1.3 Stream coarse surface boxes around a nearby ship (`planet.sync`)

## 2. View
- [x] 2.1 `view/planet.lua`: shader-lit sphere (3D fbm land/ocean, terminator, ocean specular), heightfield terrain, lit-side atmosphere and optional clouds
- [x] 2.2 `view/render.lua`: draw the body, extend the far plane, hide the sky billboard on a planet, city's air over the cap

## 3. Cities
- [x] 3.1 `sim/citygen.lua` and `view/cityroads.lua`: concentric plan, ring roads and radials, central spire, distinct silhouettes and colours per ring
- [x] 3.2 `sim/citymega.lua`: outer districts in an annulus around the circular core
- [x] 3.3 State version 24; seed-42 slice and co-op replays re-recorded

## 4. Verification
- [x] 4.1 `tests/lua/planet_spec.lua`: tangent street, determinism, body kinds, heart bay, smooth globe and terrain, sky billboard, landing and clamp
- [x] 4.2 `tests/lua/city_spec.lua`: concentric core and rings, disk footprint, tallest towers at the core
- [ ] 4.3 Local gate (`openspec validate --all --strict`, coverage >= 95% C and Lua)
- [x] 4.4 Screenshots: planet far + close with terminator, city from above showing ring roads, oblique, 3 street-level districts, city edge with planet terrain (shots_planet/v4/)
