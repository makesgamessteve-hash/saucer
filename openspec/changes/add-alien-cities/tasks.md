## 1. Civ-shaped cities (part 1)
- [x] 1.1 Tower forms by massing (`citygen.FORMS`, `MASSING_FORMS`, `BASE_FRAC`), inside the footprint
- [x] 1.2 District values and labels (`citygen.archetypes`, own rng) and value forms (`citygen.form_of`)
- [x] 1.3 Sky lanes (`citygen.lanes`)
- [x] 1.4 City phenomena: swarms, machines, lane pulses (`view/cityphen.lua`, drawn by `view/render.lua`)
- [x] 1.5 `tests/lua/aliencity_spec.lua`; screenshots (`tools/shots/alien_city.lua`)

## 2. Megascale (part 2)
- [ ] 2.1 A 12-20 km core of 24-48 districts, 3-5 strata, canyon avenues
- [ ] 2.2 Lazy district generation in time slices (6 ms desktop, 4 ms web), active set (9 per player, 16 co-op)
- [ ] 2.3 Taken loot and opened doors as per-district diffs; state version bump, replays re-recorded
- [ ] 2.4 LOD L0-L3 and the horizon band; perf gate 16.6 ms p95

## 3. Organs and the undercity (part 3)
- [ ] 3.1 The best building in each district as a mini relic (relicgen spaces), fold bays on terraces
- [ ] 3.2 The undercity warrens; the remaining add-cities tasks (transit and storm extras, mystery tie-ins)
