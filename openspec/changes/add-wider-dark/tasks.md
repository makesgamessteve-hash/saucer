## 1. Galaxy and civilizations

- [x] 1.1 `sim/galaxy.lua`: seven sectors, a spine of four to the Heart, links, danger, hops, names
- [x] 1.2 `sim/sector.lua` far sectors (3-4 sites, civ kits, danger); the home sector unchanged
- [x] 1.3 `sim/civs.lua` trait generator (`civs/traits.lua`): names, bodies, shapes, kits, domains, tint, music
- [x] 1.4 Party fold jumps: propose on the map, everyone agrees, everyone ready, spool, formation arrival
- [x] 1.5 Per-sector stash of world state and per-player memory; Fold Core tiers at traders

## 2. Co-op

- [x] 2.1 Engine: frames for every slot with co-op on, replay `slots`, joins refused in XR
- [x] 2.2 Split keyboard (`key2:`, F2, `--split-keyboard`), touch Map and Decoy buttons
- [x] 2.3 Split screen follows the players in the game; 2 players side by side (`--split`)
- [x] 2.4 `sim/coop.lua`: join, gifts (eject, beam up, gift table), docking, dome visits

## 3. Xenoarchive, requests and reputation

- [x] 3.1 `sim/archive.lua`: catalogs, filing on identify, 25/50/100% rewards
- [x] 3.2 `sim/requests.lua`: three requests per trader, double pay, reputation levels and price bonus

## 4. Sentries and tools

- [x] 4.1 Clamp and Lockdown (`sim/advsentry.lua`) in danger 2+ sectors
- [x] 4.2 Decoy, Shroud and Override spike; jamming frees a Clamp

## 5. Mystery

- [x] 5.1 Witness Echo (translation gate at 25%) and Heart Key in spine sectors
- [x] 5.2 `sim/heart.lua`: the core, the vote (tie to the last Key), endings, centerpiece, effects

## 6. Presentation

- [x] 6.1 Map panel graphic and the spare split-screen quarter (`view/map.lua`)
- [x] 6.2 Clamp, Lockdown, seals, decoys, gifts, guests in a dome, the Heart's core, hive pods
- [x] 6.3 HUD: Clamp, Shroud, decoys, sector, jump vote, Heart vote; help and hint lines
- [x] 6.4 `view/music.lua` with pitched notes (`saucer.audio.play` `pitch`)

## 7. Verification

- [x] 7.1 Lua specs `tests/lua/widerdark_spec.lua`; C tests for the split keyboard, layouts and replay slots
- [x] 7.2 Game test `tests/game/widerdark.lua` (four players, party jumps, the full mystery)
- [x] 7.3 Slice replay re-recorded; coverage at least 95% for C and Lua
- [x] 7.4 Screenshot tour `tools/shots/m8.lua`
