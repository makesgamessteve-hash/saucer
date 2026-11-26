## 1. The dress
- [x] 1.1 `sim/hulldress.lua` and `civs/hulls.lua`: motif hand-out per roster, pattern by signature rule, palette from
      the civ's materials, light model signals (`signal_at`), shared geometry (`element`, `mark`, `boxes`, `orient`)

## 2. Stations
- [x] 2.1 `stationhull.civ_for` (port: the sector's first site's civ; outpost: the city's), `for_trader` passes it,
      `set_style` for shot scripts
- [x] 2.2 The crown, crest, pattern and signals in `generate` (no random numbers; inside the box; behind the cell),
      solid as drawn; the civ palette; material slots on the plating; the far silhouette's self-light
- [x] 2.3 `view/stationhull.lua`: signals out to 9 km, the civ's material slots, the plain twin when another civ holds
      the view

## 3. Relics
- [x] 3.1 `view/relic.lua`: far hulls in the civ's edge language, pattern, motif, lit bands, signals; drawn out to
      7 km; the far hull follows the builder (not always the Vyrr); `set_style` frees far hulls

## 4. Checks
- [x] 4.1 `tests/lua/civhulls_spec.lua`
- [x] 4.2 HUD-off comparison shots per civ (`tools/shots/hulls.lua`), before and after
- [ ] 4.3 Local gate (openspec strict, ctest with replays, C and Lua coverage at least 95%)
