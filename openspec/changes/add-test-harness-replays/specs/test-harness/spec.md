## ADDED Requirements

### Requirement: Replays with state hashes
The engine SHALL record and play back `.srep` replays (header + per-tick, per-player command frames) and SHALL compute a deterministic state hash every 60 ticks. Playback SHALL fail on the first hash mismatch and report the tick.

#### Scenario: Divergence
- **WHEN** a code change alters the saucer's acceleration
- **THEN** the golden replay fails, reporting the first tick whose hash differs

### Requirement: Cross-platform determinism
Golden replays and procgen hashes SHALL produce identical results on Linux, Windows, and wasm (Node) CI runners, and in the WebXR mock run.

#### Scenario: CI matrix
- **WHEN** the replay `mvp_loop.srep` runs on linux-gcc, linux-clang, windows-msvc, and emscripten/Node
- **THEN** all final state hashes are equal

### Requirement: Coverage gates
CI SHALL fail when C line coverage (excluding `engine/src/platform/`) or Lua line coverage (`data/base/scripts`) falls below 95%, or C branch coverage falls below 85%.

#### Scenario: Under-tested change
- **WHEN** a PR drops Lua coverage to 94.2%
- **THEN** the coverage job fails and reports the uncovered files
