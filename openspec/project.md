# Saucer — project conventions

Saucer is a retro-3D exploration game: you live in a flying saucer whose glass
dome is a villa, and shrink it down to a one-seat car to get into derelicts and
pick up loot. Design source: the concept document v0.3 (§16 lists the
capabilities and the change order 0–21 used here).

## Stack
- C11 engine core (`engine/src/core`), no SDL: everything that is unit tested.
- Platform layer (`engine/src/platform`): SDL3, OpenGL 3.3 core / WebGL2
  (GLES 3.0), SDL audio streams, WebXR glue in `web/`.
- Gameplay in Lua 5.4 (`data/base/scripts`), loaded as the `base` mod through
  the same `saucer.*` API (`api = 1`) that user mods get.
- Mesh geometry comes only from Lua recipes (`data/base/meshes/<id>.lua`
  returning `function(params, rng)`); there are no mesh files.

## Targets
Windows (MSVC), Linux (GCC, Clang), Web (emscripten, WebGL2, WebXR). macOS is
out of scope. Touch controls for mobile web ship in milestone 1.

## Determinism rules (concept §14.1)
- The sim advances in fixed 1/60 s ticks and only reads command frames
  (buttons, edges, quantized axes, aim). Rendering, audio and UI never feed it.
- Seeds: PCG32 streams; child seed = `mix64(parent ^ hash64(tag) ^ index)`.
- Sim math only through `saucer.math` (deterministic sin/cos/atan2/sqrt,
  16.16 fixed point). Builds use `-ffp-contract=off` / `/fp:precise`.
- Lua is built with a fixed string-hash seed; sim code iterates non-array
  tables with `saucer.util.sorted_pairs`; `os.time`, `os.clock`, `io` and
  `math.random` are not available to mods.
- State hash = canonical serialization ("SXS1") of the state table; replays
  store a hash every 60 ticks and fail on the first divergence.
- Every player has their own saucer, hold, credits, Charge and hot/banked
  loot; viewports are a list so split screen and XR stereo share one path.

## Testing and gates
- C unit tests (`tests/c`) and Lua specs (`tests/lua`): **≥ 95 % line
  coverage** each, gcovr over `engine/src/core` and luacov over
  `data/base/scripts` (`tools/coverage.sh`).
- Game tests (`tests/game/*.lua`) run headless with fixed seeds; replays in
  `tests/replays/*.srep` must reproduce their hashes on every platform.
- Each spec scenario maps to at least one named test (see each change's
  `tasks.md` for the mapping).

## Licensing
- Code: MIT. Hand-made or code-generated art and sound: CC BY 4.0.
- Images generated with Grok Imagine: `LicenseRef-xAI-Output` ("Created with
  Grok"), every prompt in `art/prompts/log.jsonl`.
- Every asset has a `.meta.lua` sidecar; `tools/artpipe/artpipe.py lint` runs
  in CI. See `LICENSING.md`.

## Process
Every feature starts as a change in `openspec/changes/<id>/` (proposal, tasks,
spec deltas). A change is archived into `openspec/specs/` only when all of its
scenarios pass in CI. Milestone 1 implemented parts of many changes; each
`tasks.md` marks what is done and what is still open.
