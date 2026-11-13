## 1. Requirements

- [x] 1.1 Player-indexed state: state.players[i]; tests/game/coop.lua
- [x] 1.2 One saucer per player: coop.lua "player 2 shrank / player 1 did not", "Charge is per player"
- [x] 1.3 Saucers are obstacles to each other: coop.lua "saucers are solid to each other"
- [ ] 1.4 Anti-blocking fold-phase: not implemented in milestone 1
- [x] 1.5 Per-player loot instances: coop.lua "each player gets their own loot instances"
- [ ] 1.6 Shared-object claims: no shared objects exist yet in milestone 1
- [x] 1.7 Multiple viewports: --viewports 1/2/4 layout; C test `render_frame_lists_and_layout`
- [x] 1.8 Snapshot and restore: game_slice_restore_every_tick (snapshot+restore before every tick, same final hash)

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
