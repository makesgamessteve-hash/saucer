## 1. Pocket configuration

- [x] 1.1 `pocket` config in `saucer/configs.lua`, size action `size3`, mesh in `meshes/saucer.lua`
- [x] 1.2 Docked-only pocketing with reasons, fold into the hand, F to hold the coin (`sim/visit.lua`)
- [x] 1.3 Unpocket only in a hangar with a free bay, grow onto the pad, board at the bay

## 2. Station interiors

- [x] 2.1 `walk` section of `kits/station.lua` and `station/folk.lua`
- [x] 2.2 Deterministic layout, furnishing, NPCs and nav graph (`sim/stationgen.lua`)
- [x] 2.3 Detail-pass rendering, folk, hand and coin, morph animation (`view/station.lua`, `meshes/npc.lua`, `meshes/hand.lua`)
- [x] 2.4 HUD: coin state, thief bearing and escape bar, prompts

## 3. Life on the station

- [x] 3.1 Vendors, chandler services, bar drinks and rumours
- [x] 3.2 Pickpocket stalk, spook, steal, flee, catch; the fence (buy back, trade, plead)

## 4. Verification

- [x] 4.1 `tests/lua/station_spec.lua`
- [x] 4.2 Game test `tests/game/station.lua` (also restore-every-tick and seed 7)
- [x] 4.3 Slice replay re-recorded; coverage at least 95% for C and Lua
- [x] 4.4 Screenshot tour `tools/shots/m5.lua`
