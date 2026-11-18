## ADDED Requirements

### Requirement: Primitive mesh building
The engine SHALL build meshes from Lua-declared primitives (box, wedge, cylinder, cone, sphere, hemisphere, ring, lathe, extrude) and operations (transform, mirror, radial_array, linear_array, merge), with per-part material, palette, and UV mode (box, cylindrical, spherical, planar).

#### Scenario: Kit module
- **WHEN** `saucer.mesh.build{parts={{box={4,4,4}},{cylinder={r=1,h=4}}}}` is called
- **THEN** a mesh is returned whose quantized vertex/index hash matches the committed reference

### Requirement: Hero meshes from recipes
All base-game meshes, including the saucer in each size configuration, every sentry, the trader station, and the cockpit console, lever, and throttle orb, SHALL be produced from Lua recipes in `data/base/meshes/`. The base game SHALL NOT ship mesh files.

#### Scenario: Saucer per config
- **WHEN** `meshes/saucer.lua` is built with `config = "villa"` and `"seat"`
- **THEN** two meshes are returned whose bounding cylinders match the hull sizes in `saucer/configs.lua` within 1 cm

#### Scenario: No mesh files
- **WHEN** CI scans `data/base/`
- **THEN** it finds no `.glb`, `.gltf`, `.obj`, or `.vox` files

### Requirement: Deterministic recipes
Recipes SHALL use only their `params`, the `rng` they're given, and `saucer.math`. The same recipe and params SHALL produce the same quantized hash (positions at 1/1024 m) on every platform.

#### Scenario: Civ variant
- **WHEN** `meshes/watcher.lua` is built with civ seed `0x51` on Linux, Windows, and wasm
- **THEN** all three hashes are equal, and a different civ seed gives a different hash

### Requirement: Declared collision and named nodes
Recipes SHALL declare collision shapes explicitly, and the sim SHALL use only those shapes. Recipes SHALL expose named nodes with pivots so Lua can animate them.

#### Scenario: Animated eye
- **WHEN** a Watcher's script rotates node `eye` by 30°
- **THEN** only the eye's geometry moves, and the Watcher's collision shape is unchanged

### Requirement: Build budget and cache
A hero mesh SHALL have at most 3k triangles and build in at most 5 ms on desktop (20 ms on web). Results SHALL be cached by `hash(recipe id, params, mod set)`.

#### Scenario: Second request
- **WHEN** the same recipe and params are requested twice
- **THEN** the second request returns the cached mesh without rebuilding
