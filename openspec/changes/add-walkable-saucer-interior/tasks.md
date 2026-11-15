## 1. Concept

- [x] 1.1 concept.md v0.4 (status, §0 decisions, §2 loop, §3.1–3.5, §5.4 scale, §10 controls, §16 changes); copy in `docs/concept.md`

## 2. Requirements

- [x] 2.1 First-person avatar on foot: `sim/avatar.lua`; specs "walks forward along +z…", "turns with the turn axis and clamps the pitch", "walks in the XR head direction"; game test `boot.lua` (touch stick walks, XR walking follows the head)
- [x] 2.2 Walkable two-deck Villa: `saucer/interior.lua`, `meshes/interior.lua`; specs "has a dome deck over a lower deck joined by stairs", "names the rooms people expect", "keeps every solid piece inside its deck", "bumps into furniture…", "walks down the stairs…", "cannot step into the stairwell…"; game test `interior.lua` (kitchen, living room, stairs, engine room, bedroom, walls block, back to the helm)
- [x] 2.3 Glass dome: ghost-drawn hemisphere (`glass` part); screenshots `docs/shots/kitchen_dome.png`
- [x] 2.4 Take and leave the helm: specs "takes the helm near it, flies, and stands up again", "walks on foot while the saucer holds station"; game tests `slice.lua` step 1 and `boot.lua` (touch Use, XR trigger stands up)
- [x] 2.5 Reconfigure around the player: specs "reconfigures around the pilot's eyes", "can fold around any eye point and facing (on foot)", "folds into the Seat around the player on foot…"; render `pose()` fold animation; `coop.lua` (player 2 folds on foot)
- [x] 2.6 Tractor from the helm or on foot: specs "tractors loot into the hold…", "tractors from on foot, aiming through the glass dome"; `slice.lua` grabs vault and duct loot
- [x] 2.7 Two sizes: spec "has two sizes: the Villa with rooms and the one-seat car"; "folding to the Seat costs 20 Charge, unfolding half that"
- [x] 2.8 Unfold needs clearance, says where: spec "blocks unfolding without clearance, keeps Charge and says where"; red ghost hull at the requested spot
- [x] 2.9 Derelict scale: spec "halls take the whole Villa; ducts need the Seat"; `slice.lua` flies the Villa through the great halls into the vault, folds to the Seat for a duct, unfolds in the hall (seeds 42 and 7, restore every tick)

## 3. Verification

- [x] 3.1 Lua specs, C unit tests and game tests pass; coverage ≥ 95 % (C and Lua)
- [x] 3.2 `tests/replays/slice_seed42.srep` re-recorded; new hashes in the commit message
- [x] 3.3 CI green on linux-gcc, linux-clang, windows-msvc, emscripten and lint; Pages deployed
- [ ] 3.4 Archive this change after CI is green
