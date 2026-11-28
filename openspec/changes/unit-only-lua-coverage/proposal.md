## Why

Steve asked for Lua code coverage to come only from unit tests ("Please just only unit tests for code coverage"). Today `tools/coverage.sh` also runs about 30 whole game scenarios under luacov. luacov's line hook makes the sim 20-40x slower, so the local gate took about two hours (mystery alone 75 minutes, city 39) while the real tests took minutes. Coverage of whole scenarios is also a weak signal: a scenario touches a line without asserting anything about it.

## What Changes

- **Lua line coverage is measured from the unit specs only** (`tests/lua/*_spec.lua`). Each spec file runs under luacov in its own process, in parallel, and the stats are merged, so the slowest single file sets the pace.
- **Game scenarios and replays still run** as ctest tests (and in the C coverage run), just without the luacov hook. They no longer count towards the Lua number.
- **The thresholds do not change:** Lua >= 95% (now from specs alone), C lines >= 95%, C branches >= 85%.
- New unit specs cover the modules that the scenarios used to cover.
- `tools/coverage.sh`, the local gate, the CI job, README and project conventions are updated to match.

## Impact

- Specs: `test-harness` (MODIFIED: Coverage gates)
- Code: `tools/coverage.sh`, `local-tools/gate.sh` (outside the repo), `.github/workflows/ci.yml`, `README.md`, `openspec/project.md`, `openspec/config.yaml`, `docs/concept.md`
- Tests: new and extended `tests/lua/*_spec.lua`
- No game code, no state version change.
