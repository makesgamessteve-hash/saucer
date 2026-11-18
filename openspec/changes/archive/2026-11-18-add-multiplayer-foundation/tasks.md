## 1. Requirements

- [x] 1.1 Player-indexed state: state.players[i]; tests/game/coop.lua
- [x] 1.2 One saucer per player: coop.lua "player 2 shrank / player 1 did not", "Charge is per player"
- [x] 1.3 Saucers are obstacles to each other: coop.lua "saucers are solid to each other"
- [x] 1.4 Anti-blocking fold-phase: tests/lua/coop_gaps_spec.lua "a friend parked in a duct: pushed for 2 s, then phased for 3 s, then solid again", "an overlapping spawn passes", "a morphing saucer is not a wall", "saucers phase through each other once the party has agreed to fold", "growing next to a friend is still refused"
- [x] 1.5 Per-player loot instances: coop.lua "each player gets their own loot instances"
- [x] 1.6 Shared-object claims (Echoes, the Curio, gifts, twin vaults and anchors): tests/lua/coop_gaps_spec.lua "the tie rule: lowest (record index + tick) mod n wins", "two beams finishing on the same echo the same tick", "on a real tick two Villas over the same twin anchor", "a pull that finishes on something the other player already claimed is refused"; and the twin-hold timeout "a hold nobody takes up lets go after HOLD_TIME"
- [x] 1.7 Multiple viewports: --viewports 1/2/4 layout; C test `render_frame_lists_and_layout`
- [x] 1.8 Snapshot and restore: game_slice_restore_every_tick (snapshot+restore before every tick, same final hash)

## 2. Verification

- [x] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten. Verified at suite level at archive time (2026-11-18): the scenarios are exercised by the C unit tests, game tests and Lua specs named in the requirement tasks above and in the capability spec; the whole suite (ctest 41/41, 385 Lua specs, coverage gates C 98.3% and Lua 98.29%) is green on all four CI platforms in main run 44391736871 (merge 88e7b05). Scenarios were not individually re-mapped in housekeeping.
- [x] 2.2 Archive this change (`openspec archive`) after CI is green (archived as `2026-11-18-add-multiplayer-foundation`)

## 3. Deferred

Moved to `later-followups` 5.1 and 5.2: the tap-the-stick push timer and claims over a laggy link.
