## MODIFIED Requirements

### Requirement: Coverage gates
CI SHALL fail when C line coverage (excluding `engine/src/platform/`) or Lua line coverage (`data/base/scripts`) falls below 95%, or C branch coverage falls below 85%. Lua line coverage SHALL be measured from the Lua unit specs (`tests/lua`) alone; game scenarios and replays SHALL still run as tests but SHALL NOT run under the coverage hook or count towards the Lua number.

#### Scenario: Under-tested change
- **WHEN** a PR drops Lua coverage to 94.2%
- **THEN** the coverage job fails and reports the uncovered files

#### Scenario: Scenarios do not count as Lua coverage
- **WHEN** a Lua line is run only by a game scenario and by no unit spec
- **THEN** it counts as uncovered, and the game scenario still runs in ctest
