## Why

Embedded Lua 5.4 with the saucer.* API v1, hooks with command frames, instruction budget and a read-only render state.

Change 4 of 0–21 in the order of concept v0.3 §16.2.

## What Changes

- ADDED `lua-runtime`: Lifecycle hooks
- ADDED `lua-runtime`: Instruction budget
- ADDED `lua-runtime`: Render cannot mutate the sim

## Impact

- Capability `lua-runtime` (`openspec/specs/lua-runtime/spec.md` once archived)
- Milestone 1 status: **done** (3/3 requirements fully met)
