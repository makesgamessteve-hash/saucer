## 1. Generation
- [x] 1.1 City kits for planet, moon and asteroid (`data/base/kits/city_*.lua`)
- [x] 1.2 `sim/citygen.lua`: plan, lots, hall stacks, undercity, tunnels, towers, bridges, rock shell, vault, gates
- [x] 1.3 `ruin.generate` dispatch and `ruin.layout_hash` export
## 2. Sites and the grid
- [x] 2.1 City sites in far sectors, map tags, entry text
- [x] 2.2 `sim/cities.lua`: power grid, couplings, gates, beacon, panel rows
- [x] 2.3 Sentries: calm halls, dark districts; clamps, lockdown and warden respect both
- [x] 2.4 Gravity: Charge cost, hangar refill, settling at zero Charge
## 3. View
- [x] 3.1 Per-district coarse meshes and chunk streaming, short detail range, gates drawn
- [x] 3.2 Environment per body, city map, HUD beacon
- [x] 3.3 Mesh table 1024 -> 4096
## 4. Tests and evidence
- [x] 4.1 `tests/lua/city_spec.lua`, `tests/game/city.lua` (ctest `game_city`, coverage loop)
- [x] 4.2 Screenshots per body (`tools/shots/cities.sh`), frame time (`tools/shots/cities_perf.sh`)
- [x] 4.3 Coverage gate (C 98.3%, Lua 98.39%); CI on main watched after the merge
## 5. Not built here (moved on 2026-11-24)
- [x] 5.1 Lazy district generation: moved to `later-followups` 7.1, for the planned `add-alien-cities` change
- [x] 5.2 Transit rails, storms, falling bridges, flooded undercity: built in `add-cities-2` (3.1, 3.2); canals moved to `later-followups` 7.2
- [x] 5.3 Mystery tie-ins and trader stations near cities: built in `add-cities-2` (4.1, 4.2); grid hand-locks moved to `later-followups` 7.2
