## 1. Warren layout
- [x] 1.1 Lattice of halls on levels: the main way carved first, growth, loops; trunks and shafts with doors from
      parent to child (a loop's second door opens from the far side)
- [x] 1.2 The heart past the last row, entered from the lowest level only; its engine column as a solid
- [x] 1.3 The lung (a big hall without a floor hole) with four bays and the locked reliquary's branch, any side
- [x] 1.4 Seat branches off every hall (one, and a second in big halls), each with a fold bay by its port
- [x] 1.5 Loot in halls (never over a hole), chambers and the reliquary; the idol before the engine
- [x] 1.6 Validation: levels, chambers, Villa space count, phenomena inside their rooms; the shortest route

## 2. Phenomena
- [x] 2.1 Placement from the civ's weighted list (`language.phenomena`), deterministic
- [x] 2.2 `view/phenomena.lua`: eight kinds posed from the clock and the eye only

## 3. Skins and drawing
- [x] 3.1 `big_room` for any long axis; ports and shafts in cushion faces; frames on every door and hatch
- [x] 3.2 Lobes skip ports, shoulders round every neighbour, roofs round a shaft; lobes grow on huge faces
- [x] 3.3 The heart's engine (spindle, rings, heart, roots) and its turning hoops
- [x] 3.4 Lazy room meshes, door-hop culling, a build budget a frame, hull boxes outside
- [x] 3.5 Lamps for trunks on either axis, shafts, chambers and the heart

## 4. Tests and shots
- [x] 4.1 `tests/lua/relic_spec.lua`: scale, loops/dead ends/shafts, no overlaps, heart depth, branches, bays,
      finds, engine, determinism and speed, phenomena (placement, poses, render-only), ports clear of skins,
      lazy meshes and the triangle cap from every room
- [x] 4.2 `tests/game/relic.lua`: the Villa flies from the maw to the heart; seeds 42 and 7
- [x] 4.3 `tools/shots/relic_slice.lua`: the warren tour (halls, trunks, shafts, the heart, chambers, phenomena)
