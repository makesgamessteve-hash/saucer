## 1. Holodeck

- [x] 1.1 Holodeck room, arch, panel and grid (`saucer/interior.lua`, `meshes/interior.lua`)
- [x] 1.2 Program discovery from `holo/` across mods, library, starters (`sim/holo.lua`)
- [x] 1.3 Walking programs (spots, arch exit, arena and solids) and the flight course
- [x] 1.4 Base programs: beach, forest, Seat course, derelict replay, alien memory
- [x] 1.5 Upgrade modules (space, detail, guest slots) installed at the panel
- [x] 1.6 Co-op guests join a running program
- [x] 1.7 Program view with its own camera, fog and props (`view/holo.lua`)

## 2. Home life

- [x] 2.1 Buffs (`home/buffs.lua`, `sim/buffs.lua`) wired into regen and cooldowns
- [x] 2.2 Galley panel, pantry and recipes (`home/kitchen.lua`, `sim/kitchen.lua`)
- [x] 2.3 Bookshelf, page view and leads (`home/books.lua`, `sim/books.lua`)
- [x] 2.4 TV channels and hints (`home/channels.lua`, `sim/tv.lua`)
- [x] 2.5 Vault finds, data cores decoded at the lab, trader shop

## 3. Verification

- [x] 3.1 `tests/lua/homelife_spec.lua`
- [x] 3.2 Game test `tests/game/holodeck.lua` and the holodeck mod fixture in `tests/game/mods.lua`
- [x] 3.3 Slice replay re-recorded; coverage at least 95% for C and Lua
- [x] 3.4 Screenshot tour `tools/shots/m4.lua`
