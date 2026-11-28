## 1. Gate
- [x] 1.1 `tools/coverage.sh`: luacov only around `--test-lua` specs, one process per spec file, merged; game scenarios stay in ctest unhooked
- [x] 1.2 `.github/workflows/ci.yml`: shorter job limits (the local gate keeps its generous timeouts so older branches still pass)
- [x] 1.3 README, `openspec/project.md`, `openspec/config.yaml`, `docs/concept.md` describe unit-only Lua coverage

## 2. Coverage
- [x] 2.1 Measure Lua coverage from the specs alone
- [x] 2.2 Add unit specs for modules below the bar so the total stays >= 95%

## 3. Verification
- [x] 3.1 Local gate (`openspec validate --all --strict`, ctest, C and Lua coverage >= 95%); record the new gate time
