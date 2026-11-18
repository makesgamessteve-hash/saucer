## 1. Requirements

- [x] 1.1 Primitive mesh building: box/wedge/cylinder/frustum/ring/dome/extrude/stars; Lua spec "builds all primitive kinds"
- [x] 1.2 Hero meshes from recipes: saucer (4 sizes), station, loot cache, derelict greebles, and (group "Meshes") the Watcher (`meshes/watcher.lua`), the Snatcher (`meshes/snatcher.lua`) and the cockpit console, size lever and throttle orb (`meshes/cockpit.lua`); specs "builds a Watcher, a Snatcher and the cockpit props within their budgets", "builds the console, the lever and the orb with their nodes", "No mesh files"
- [x] 1.3 Deterministic recipes: specs "builds every recipe with a stable hash" and "Civ variant"
- [x] 1.4 Declared collision and named nodes: `nodes` and `collision` in recipes, `lib/volume.lua`, `kit.rig`/`kit.draw`/`kit.volumes`; used by the Watcher (head yaw, eye pitch), the Snatcher (claws, eye), the Jammer and the Override spike (reach to the hit volumes) and the XR lever (handle, grab volume); specs "Animated eye", "a child node follows its parent's yaw", "rejects badly declared nodes and collision", "a Watcher's and a Snatcher's reach", "the Jammer reaches a sentry by its volume", "the Override spike reaches a disabled sentry by its volume", "the lever's grab volume", "collision volumes (lib/volume.lua)"
- [x] 1.5 Build budget and cache: 3k triangles / 5 ms hero default (20 ms web), per-recipe ceilings in `meshes/budgets.lua`; strict mode errors, otherwise a magenta box stands in and the violation is recorded; build time over the limit warns; cache: "caches and reloads" and "the view's asset cache hands out each rig once (Second request)"; specs under "build budget"

## 2. Verification

- [x] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten (all five scenarios of the spec map to `tests/lua/mesh_rigs_spec.lua` and `tests/lua/lib_spec.lua`). Verified at suite level at archive time (2026-11-18): the scenarios are exercised by the C unit tests, game tests and Lua specs named in the requirement tasks above and in the capability spec; the whole suite (ctest 41/41, 385 Lua specs, coverage gates C 98.3% and Lua 98.29%) is green on all four CI platforms in main run 44391736871 (merge 88e7b05). Scenarios were not individually re-mapped in housekeeping.
- [x] 2.2 Archive this change (`openspec archive`) after CI is green (archived as `2026-11-18-add-mesh-builder`)

## 3. Deferred

Moved to `later-followups` 3.1-3.3: a Watcher LOD, per-civ body scale, measured web build times.
