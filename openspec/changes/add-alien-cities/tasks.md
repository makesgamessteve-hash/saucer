## 1. Civ-shaped cities (part 1)
- [x] 1.1 Tower forms by massing (`citygen.FORMS`, `MASSING_FORMS`, `BASE_FRAC`), inside the footprint
- [x] 1.2 District values and labels (`citygen.archetypes`, own rng) and value forms (`citygen.form_of`)
- [x] 1.3 Sky lanes (`citygen.lanes`)
- [x] 1.4 City phenomena: swarms, machines, lane pulses (`view/cityphen.lua`, drawn by `view/render.lua`)
- [x] 1.5 `tests/lua/aliencity_spec.lua`; screenshots (`tools/shots/alien_city.lua`)

## 2. Megascale (part 2)
- [x] 2.1 Outer districts round the core (`sim/citymega.lua`): a ~21 km footprint, 24-48 districts in all, civ-shaped
      megaforms up to 1.5 km (one city megaform up to 2.8 km), canyon avenues over shared foundations, strata decks;
      kept clear of the core, the spaceport approach, the sector's heart, every other site, the stations and the arrival
- [x] 2.2 Streaming: districts solid only within 1.5 km of a ship (9 per player, 16 in all), built there and then if
      the view has not; the view builds ahead in a 6 ms budget (4 ms web); the physics list sheds removed tail boxes
- [x] 2.3 Moved to part 3 (3.3): the outer districts hold no loot or doors yet, so no diffs or version bump here
- [x] 2.4 LOD (full mesh + lit windows to 4 km, lit silhouettes to 40 km, a horizon band at 26-50 km), a 60 km far
      plane over a megacity, backdrop sprites drawn with the sky; `tools/shots/megacity_perf.lua` (frame p95)
- [x] 2.5 `tests/lua/megacity_spec.lua`, `tests/game/megacity.lua`, shots `tools/shots/megacity.lua`

## 3. Organs and the undercity (part 3)
- [x] 3.1 Every outer district's organ (its tallest ordinary megaform) is hollow at the street: a 60-110 m hall behind a
      mouth facing the avenue, 4-6 finds and a slow turning machine (`citymega.plan_organ`, `view/citymega.lua`)
- [x] 3.2 Drifters: glowing slabs gliding down the outer avenues, turning and bobbing, render only
- [x] 3.3 Taken organ finds are per-player `looted` keys (`mega<site>:<district>:<find>`), saved with the rest: no new
      state, no version bump, replays unchanged
- [ ] 3.4 (later) Relicgen interiors in the organs, fold bays on terraces, the undercity warrens, transit and storm
      extras in the ring, mystery tie-ins
