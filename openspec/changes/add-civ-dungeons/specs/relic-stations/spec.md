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

### Requirement: Civ heart machines
The heart's engine SHALL turn a machine drawn from its civ's language (hoop count from the symmetry, speed from the tempo, tilt from the organic warp, stacked hoops for spine and helix builders), render-only, while the slice's Vyrr keep their three tilted hoops.

#### Scenario: Machines
- **WHEN** `tests/lua/civdungeon_spec.lua` runs "turn three tilted hoops for the Vyrr and the civ's own machine for others"
- **THEN** it passes

### Requirement: Hall landmarks
Every big hall of a relic (footprint at least three quarters of its largest hall's) SHALL hang one render-only landmark whose kind comes from the builder civ's primitives and whose parts move with the clock, staying clear of the walls, the floor and the ceiling lamp, without changing the generated layout.

#### Scenario: Landmarks in every archetype
- **WHEN** `tests/lua/civdungeon_spec.lua` runs "hangs one in every big hall of every archetype, clear of the walls, floor and ceiling lamp"
- **THEN** it passes

### Requirement: Relic radar outlines
Inside a relic the helm radar SHALL close in and outline every room the saucer has been in, nearest first and capped, as a view-side memory that never enters the state.

#### Scenario: Outlines
- **WHEN** `tests/lua/civdungeon_spec.lua` runs "closes the helm radar in inside a relic and outlines the rooms the saucer has been in"
- **THEN** it passes
