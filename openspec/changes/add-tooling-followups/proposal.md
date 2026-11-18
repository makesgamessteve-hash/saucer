## Why

Housekeeping (2026-11-18) archived every finished OpenSpec change. Seven tooling items were
still open as "(partial)" tasks inside those changes. Steve did not ask for them, so they were
moved out of the original changes into this one, where they wait until somebody wants them.
Nothing here blocks the game or CI.

## What Changes

- Art pipeline: an `artpipe verify` command, size conformance in `artpipe lint`, and a generated
  `REUSE.toml` (from `add-art-pipeline-tools` 1.4, 1.5, 1.6).
- Determinism: a Lua-level `saucer.rng.new(42)` known-answer vector and a luacheck rule for
  unsorted `pairs` in sim code, in CI (from `add-deterministic-sim` 1.1, 1.4).
- Ruin generation: a measured time budget (from `add-ruin-generation-mvp` 1.4).
- Web build: load assets on demand instead of all of `data/index.json` at startup (from
  `add-asset-vfs-and-mod-loading` 1.1).

## Impact

- Tooling, CI and the web loader only; no change to the simulation, saves or replays.
- No spec deltas (`skip_specs`): the behaviour is already specified by the archived capabilities
  `art-pipeline`, `deterministic-sim`, `ruin-generation` and `asset-vfs`.
- Not moved, because they turned out to be done: the MSVC replay-hash check (the `windows-msvc` CI job
  runs every `replay_*` ctest against the Linux hashes; `add-test-harness-replays` 1.2) and
  "Windows MSVC job not yet run" (`add-engine-core-headless` 1.3).
