## MODIFIED Requirements

### Requirement: City silhouette and light colour
A city's towers SHALL be stacked tiers in a silhouette chosen by the civilisation's massing (crater crown, ribbed spine, pods, stacked cells, terraces, lattice, helix or lobes), or by its shape when it has no massing, every tier inside the tower's footprint so that the collision equals the drawing, the first tier the full footprint, wearing the civilisation's light colours with window patterns, signs, ledges and roof greebles that are the same on every visit.

#### Scenario: each civilisation builds its own silhouette and wears its own light colours
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: every silhouette stays inside its footprint, so what you see is what you hit
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a styled kit wears the civ's colours and leaves the shared kit alone
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: window patterns are the same every time and tower tiers differ
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: civ forms
- **WHEN** `tests/lua/aliencity_spec.lua` runs "builds every civ form inside its footprint, the first tier the full footprint" and "takes the tower form from the builders' massing, else from the old shape"
- **THEN** both pass

## ADDED Requirements

### Requirement: District values
Every ordinary city district SHALL stand for a value, the builders' own for about 60% and another for the rest, drawn from its own random stream so rooms, doors, slots and landmarks do not change. It SHALL be labelled by that value (Archive Spires, Treasury Vaults, Cathedral Organs, Brood Warrens, Fortress Terraces, Foundry Trenches, Choir Bowls) and every other tower in it SHALL take that value's form. Landmark districts SHALL keep their kinds and labels.

#### Scenario: Values and forms
- **WHEN** `tests/lua/aliencity_spec.lua` runs "gives ordinary districts the builders' values, landmarks keep theirs" and "draws the value's form in its districts and leaves rooms and doors as they were"
- **THEN** both pass

### Requirement: Sky lanes
A city SHALL have a sky lane between every pair of neighbouring districts, level, high over the core's towers.

#### Scenario: Lanes
- **WHEN** `tests/lua/aliencity_spec.lua` runs "runs a sky lane between every pair of neighbouring districts, high over the towers"
- **THEN** it passes

### Requirement: City phenomena
A city SHALL show harmless goings-on: a swarm of motes over every district that parts round the saucer, a ring and arms cycling on each district's tallest tower, and light pulses running down every sky lane. They SHALL be render only, a pure function of the clock and the eye, never colliding and never touching the state.

#### Scenario: Swarms, machines and pulses
- **WHEN** `tests/lua/aliencity_spec.lua` runs "places swarms, machines and lane pulses, all harmless functions of the clock"
- **THEN** it passes
