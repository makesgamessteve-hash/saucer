## 1. Requirements

- [x] 1.1 License field on every asset: .meta.lua sidecars; `artpipe lint`
- [x] 1.2 Separated generated assets: data/base/generated vs data/base/authored
- [x] 1.3 Prompt record for every generated asset: art/prompts/log.jsonl + prompt in each sidecar
- [ ] 1.4 Reproducible processing (partial): `artpipe build` is deterministic; `artpipe verify` command not yet written
- [ ] 1.5 Palette and size conformance (partial): artpipe quantizes to the palette; lint does not yet check sizes
- [ ] 1.6 Generated licensing files (partial): ATTRIBUTION.md generated; REUSE.toml hand-written
- [x] 1.7 xAI terms reference: LICENSES/LicenseRef-xAI-Output.md with URLs and retrieval date

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
