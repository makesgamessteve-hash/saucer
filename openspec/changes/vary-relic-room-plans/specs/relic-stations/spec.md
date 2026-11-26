## ADDED Requirements

### Requirement: Relic room-plan patterns
A styled relic SHALL be laid out by its civ's massing pattern (a spiral, diamond, shells, rings, helix, Sierpinski gasket, H-tree or recursive spine) so the room-plan map is not a filled rectangle, with the heart hall in a reserved centre, while keeping every relic gate (main way saucer-size to the heart, fold bays by Seat ports, the Charge plan, at least three levels, 40-80 Villa spaces). The slice's Vyrr relic SHALL keep the kit's warren.

#### Scenario: The slice is unchanged
- **WHEN** `tests/lua/civdungeon_spec.lua` runs "keeps the slice's Vyrr warren hash"
- **THEN** it passes

#### Scenario: Heart in the centre
- **WHEN** `tests/lua/civdungeon_spec.lua` runs "names a pattern for every massing archetype and puts the heart inside the halls' footprint"
- **THEN** it passes

#### Scenario: Not a filled rectangle
- **WHEN** `tests/lua/civdungeon_spec.lua` runs "leaves the centre of a ring or shell empty of halls (not a filled rectangle)"
- **THEN** it passes

#### Scenario: Seed variation
- **WHEN** `tests/lua/civdungeon_spec.lua` runs "varies a spiral or helix with the seed (handedness or start)"
- **THEN** it passes

#### Scenario: Existing archetype gates still hold
- **WHEN** `tests/lua/civdungeon_spec.lua` runs "lays every archetype out by its own grammar, the heart reachable from the maw"
- **THEN** it passes
