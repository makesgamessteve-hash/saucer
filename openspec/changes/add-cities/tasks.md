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
- [ ] 4.3 Coverage gate and CI green on main
## 5. Not built
- [ ] 5.1 Lazy district generation (generation is eager inside a 420-room budget; render is streamed)
- [ ] 5.2 Transit rails and canals; collapsing structures; storms; a flooded undercity
- [ ] 5.3 Mystery tie-ins; on-foot hand-locks for the grid; trader stations near cities
