## 1. Networking

- [x] 1.1 `sx_net`: lockstep protocol (hello, welcome, reject, input with acks, hashes, bye), transport-agnostic
- [x] 1.2 `sx_net_udp`: desktop UDP host and join; `--host`, `--join`, `--net-players`, `--net-delay`
- [x] 1.3 Engine: frames for every slot from the session, the guest's slot joins on its first frame, `saucer.net.status()`
- [x] 1.4 Web: `web/saucer_net.js` WebRTC bridge, offer and answer codes, the Online co-op panel
- [x] 1.5 XR players: headset views follow the local slot
- [x] 1.6 Compact split HUD for two and four players; window title shows the network status

## 2. The dome

- [x] 2.1 `sim/decor.lua`: furniture, the Home planner, solid pieces for guests
- [x] 2.2 Display slots, garden beds, harvests, Comfort and Charge regeneration
- [x] 2.3 Furniture and seeds at traders; admiring a host's display

## 3. Sentries and tools

- [x] 3.1 `sim/warden.lua`: layout, patrol, hunt, Snatcher wake-up, Jammer and Override
- [x] 3.2 `sim/tools.lua`: grapple and cutter

## 4. Mods and Hardcore

- [x] 4.1 Mod browser (`sim/modbrowser.lua`, `saucer.mods`, `mods.txt`)
- [x] 4.2 `sim/hardcore.lua`: the title card choice, Fold Retreat, Lifeline, no loading

## 5. Verification

- [x] 5.1 C tests `tests/c/test_net.c` (lossy lockstep, four players, desync, rejects, timeouts)
- [x] 5.2 Lua specs `tests/lua/homestars_spec.lua` and additions to the excursion and wider-dark specs
- [x] 5.3 Game tests: two-process loopback (`game_netplay`, `game_netplay_seed7`, `game_net_desync`), `game_mod_browser`
- [x] 5.4 Headless node test of the web transport `tests/web/net_web.test.js`
- [x] 5.5 Coverage at least 95% for C and Lua; screenshot tour `tools/shots/m9.lua` and `tools/shots/m9_net.sh`
