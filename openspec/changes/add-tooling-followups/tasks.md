## 1. Tooling follow-ups (all open, none requested yet)

- [ ] 1.1 `artpipe verify`: rebuild every generated asset into a scratch folder and fail when any byte differs from `data/base/generated` (was `add-art-pipeline-tools` 1.4)
- [ ] 1.2 Size conformance: `artpipe lint` fails an asset whose size is not the one its recipe declares (was `add-art-pipeline-tools` 1.5)
- [ ] 1.3 Generate `REUSE.toml` from the asset licence fields, the way `ATTRIBUTION.md` is generated, and have lint fail when the committed file is stale (was `add-art-pipeline-tools` 1.6)
- [ ] 1.4 A Lua-level known-answer vector for `saucer.rng.new(42)` next to the C vectors in `tests/data/rng_kat.txt`, checked natively and under wasm (was `add-deterministic-sim` 1.1)
- [ ] 1.5 A luacheck rule (or equivalent lint) that rejects `pairs` over unordered tables in `data/base/scripts/sim`, run in the CI lint job (was `add-deterministic-sim` 1.4)
- [ ] 1.6 Ruin generation time budget: measure `ruin.generate` per kit and size, record the ceiling, and warn or fail over it (was `add-ruin-generation-mvp` 1.4)
- [ ] 1.7 Lazy web loading: fetch assets on demand (or in a few bundles) instead of every file listed in `data/index.json` at startup (was `add-asset-vfs-and-mod-loading` 1.1)

## 2. Verification

- [ ] 2.1 Each item has a named test or CI step, and `ctest` plus the coverage gates stay green
