## ADDED Requirements

### Requirement: City silhouette and light colour
A city's towers SHALL be stacked tiers in a silhouette chosen by the civilisation's shape, every tier inside the tower's footprint so that the collision equals the drawing, wearing the civilisation's light colours with window patterns, signs, ledges and roof greebles that are the same on every visit.

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

### Requirement: Lights and grid
The lights of a city SHALL be separate from its walls and burn only in a district whose grid is on: dark before its coupling is restored, a flicker then a ramp afterwards, as a pure function of the tick and the power locks; landmark districts SHALL carry a light pillar and every district a far glow.

#### Scenario: a city's windows, signs and strips are lights, split from the walls and built when wanted
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a dark district has no light, a restored one flickers and ramps up, the spaceport is always lit
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the drawn lights follow the grid: none in a dark district, many once it is restored
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a light pillar marks each landmark district, and a lit district glows from afar
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Helm hint
The control hint at the helm SHALL sit in the free band at the top centre, backed and faded, clear of the console, the status stacks and the alerts; the message log SHALL have a backing.

#### Scenario: the hint line sits at the top and a city's message log has a backing
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes
