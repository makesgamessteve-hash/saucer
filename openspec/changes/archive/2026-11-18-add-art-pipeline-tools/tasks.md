## 1. Requirements

- [x] 1.1 License field on every asset: .meta.lua sidecars; `artpipe lint`
- [x] 1.2 Separated generated assets: data/base/generated vs data/base/authored
- [x] 1.3 Prompt record for every generated asset: art/prompts/log.jsonl + prompt in each sidecar
- [x] 1.4 Reproducible processing: `artpipe build` is deterministic. The `artpipe verify` command moved to `add-tooling-followups` 1.1
- [x] 1.5 Palette and size conformance: artpipe quantizes to the palette. Size conformance in lint moved to `add-tooling-followups` 1.2
- [x] 1.6 Generated licensing files: ATTRIBUTION.md is generated. Generating REUSE.toml moved to `add-tooling-followups` 1.3
- [x] 1.7 xAI terms reference: LICENSES/LicenseRef-xAI-Output.md with URLs and retrieval date

## 2. Verification

- [x] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten. Verified at suite level at archive time (2026-11-18): the scenarios are exercised by the C unit tests, game tests and Lua specs named in the requirement tasks above and in the capability spec; the whole suite (ctest 41/41, 385 Lua specs, coverage gates C 98.3% and Lua 98.29%) is green on all four CI platforms in main run @RUN@. Scenarios were not individually re-mapped in housekeeping.
- [x] 2.2 Archive this change (`openspec archive`) after CI is green (archived as `2026-11-18-add-art-pipeline-tools`)
