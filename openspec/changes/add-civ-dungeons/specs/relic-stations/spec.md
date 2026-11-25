## ADDED Requirements

### Requirement: Civ room grammars
A relic SHALL be laid out by its civ's massing archetype and body scale, keeping every relic gate (main way saucer-size to the heart, fold bays by Seat ports, the Charge plan, at least three levels, 40-80 Villa spaces), and the slice's Vyrr relic SHALL keep the kit's warren.

#### Scenario: The slice is unchanged
- **WHEN** `tests/lua/civdungeon_spec.lua` runs "keeps the slice's Vyrr on the kit's warren"
- **THEN** it passes

#### Scenario: Archetypes differ
- **WHEN** `tests/lua/civdungeon_spec.lua` runs "lays every archetype out by its own grammar, the heart reachable from the maw"
- **THEN** it passes

#### Scenario: Body scale
- **WHEN** `tests/lua/civdungeon_spec.lua` runs "gives big bodies bigger halls and heart, tiny bodies small halls"
- **THEN** it passes

#### Scenario: Deterministic
- **WHEN** `tests/lua/civdungeon_spec.lua` runs "is deterministic and memoizes the styled kit"
- **THEN** it passes
