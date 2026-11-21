## 1. Generator and kit

- [x] 1.1 `station/hull.lua` kit: classes, palettes, LOD distances, approach corridor, budgets
- [x] 1.2 `sim/stationhull.lua`: deterministic layout, parts per layer, solids, lights, far bay
- [x] 1.3 `view/stationhull.lua`: lazy merged meshes, levels of detail, beacons, approach lights

## 2. Sim integration

- [x] 2.1 `saucer/dock.lua` retune; `sim/dock.lua` cell solids; hull solids in `game.rebuild`
- [x] 2.2 `sim/sector.lua` `place_station`; `sim/visit.lua` far hangar on a pod
- [x] 2.3 State version 15; replays re-recorded

## 3. Detail

- [x] 3.1 Hangar cell dressing in the mesh; `view/dock.lua` draws only the dynamic parts
- [x] 3.2 Interior props for the hangar and the concourse (`sim/stationgen.lua`, `view/station.lua`)

## 4. Tests and tooling

- [x] 4.1 `tests/lua/stationhull_spec.lua`; dock, station and sentries tests updated
- [x] 4.2 `tools/shots/station.lua` screenshot tour
- [x] 4.3 Coverage at least 95 percent (C and Lua), `openspec validate --all --strict`
