# deterministic-sim Specification

## Purpose
Generation and simulation are bit-identical across platforms: hierarchical seeds, deterministic math and stable Lua iteration and hashing.

## Requirements

### Requirement: Bit-identical generation across platforms
The PRNG and seed derivation SHALL produce identical outputs for identical inputs on Windows, Linux, and wasm builds.

#### Scenario: Known-answer test
- **WHEN** `saucer.rng.new(42)` draws 1,000 `int(0, 2^31-1)` values
- **THEN** they match the committed reference vector on every CI platform

### Requirement: Hierarchical seeds
Child seeds SHALL be derived as `splitmix64(parent ~ hash64(tag) ~ index)`, so generating one child never consumes another child's stream.

#### Scenario: Order independence
- **WHEN** site 5 of sector (0,0,0) is generated before or after site 2
- **THEN** site 5's layout hash is identical in both cases

### Requirement: Deterministic math in the sim
Sim code (C and Lua) SHALL use only `saucer.math` for trigonometry, square roots, and fixed-point arithmetic. The Lua sim environment SHALL replace `math.random`, `math.sin`, `math.cos`, `math.sqrt`, and similar with deterministic versions, and SHALL NOT expose `os.time` or `os.clock`.

#### Scenario: Known-answer trig
- **WHEN** `saucer.math.sin` is evaluated at 4,096 fixed inputs
- **THEN** the results match the committed vector bit-for-bit on every platform

### Requirement: Stable Lua iteration and hashing
The embedded Lua SHALL be built with a fixed string-hash seed, and sim code SHALL iterate non-array tables only through `saucer.util.sorted_pairs`, which luacheck enforces.

#### Scenario: Two runs, same order
- **WHEN** the same replay runs twice in separate processes
- **THEN** event dispatch order and the final state hash are identical
