## 1. Body
- [x] 1.1 `sim/planet.lua`: seeded sphere, tangent street, flattened rim, height/kind/colour, sector-heart bay
- [x] 1.2 Landing and hull clamp on the surface outside the rim; crust below the warren; no collision in the heart bay
- [x] 1.3 Stream coarse surface boxes around a nearby ship (`planet.sync`)

## 2. View
- [x] 2.1 `view/planet.lua`: faceted globe, terrain cap, planet atmosphere
- [x] 2.2 `view/render.lua`: draw the body, extend the far plane, hide the sky billboard on a planet, city's air over the cap

## 3. Verification
- [x] 3.1 `tests/lua/planet_spec.lua`: tangent street, determinism, body kinds, heart bay, globe and terrain, sky billboard, landing and clamp
- [ ] 3.2 Local gate (`openspec validate --all --strict`, coverage >= 95% C and Lua)
- [x] 3.3 Screenshots: planet from space, city with planet surroundings (shots_planet/)
