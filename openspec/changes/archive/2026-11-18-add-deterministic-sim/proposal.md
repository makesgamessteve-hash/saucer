## Why

PCG32/SplitMix64 seeds, deterministic math, Lua determinism rules and cross-platform known-answer tests.

Change 2 of 0–21 in the order of concept v0.3 §16.2.

## What Changes

- ADDED `deterministic-sim`: Bit-identical generation across platforms
- ADDED `deterministic-sim`: Hierarchical seeds
- ADDED `deterministic-sim`: Deterministic math in the sim
- ADDED `deterministic-sim`: Stable Lua iteration and hashing

## Impact

- Capability `deterministic-sim` (`openspec/specs/deterministic-sim/spec.md` once archived)
- Milestone 1 status: **partial** (2/4 requirements fully met)
