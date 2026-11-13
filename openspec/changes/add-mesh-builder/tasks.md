## 1. Requirements

- [x] 1.1 Primitive mesh building: box/wedge/cylinder/frustum/ring/dome/extrude/stars; Lua spec "builds all primitive kinds"
- [ ] 1.2 Hero meshes from recipes (partial): saucer (4 sizes), station, loot cache, derelict greebles; Watcher/Snatcher/cockpit props still to come
- [x] 1.3 Deterministic recipes: spec "builds every recipe with a stable hash"
- [ ] 1.4 Declared collision and named nodes: not yet
- [ ] 1.5 Build budget and cache (partial): cache implemented ("caches and reloads"); budget not enforced

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
