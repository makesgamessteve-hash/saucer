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

### Requirement: Megacity
A city's core SHALL be ringed by outer districts filling a footprint of about 21 km, 24 to 48 districts in all, each a
pure function of the city's seed, each carrying a value and standing civ-shaped megaforms up to 1.5 km tall between
canyon avenues, with strata decks; one megaform per city SHALL rise 2 to 2.8 km. What is drawn SHALL be what collides.

#### Scenario: Clear ground
- **WHEN** `tests/lua/megacity_spec.lua` runs "a city's core is ringed by outer districts, 24 to 48 districts in all"
- **THEN** it passes, with no outer district on the core, the spaceport's approach, the sector's heart, another site, a station or the arrival point

#### Scenario: The ring and its megaforms
- **WHEN** `tests/lua/megacity_spec.lua` runs "outer districts stand civ-shaped megaforms between canyon avenues, one city form up to 2.8 km"
- **THEN** it passes

### Requirement: District streaming
An outer district SHALL be solid only while a ship is within 1.5 km of it (kept until 1.75 km), at most 9 per player and
16 in all, nearest first, and SHALL be built synchronously when it is needed and not yet built. A restore SHALL make the
same districts solid from the players' positions, so a run with a restore ends in the same state as one without.

#### Scenario: Streaming
- **WHEN** `tests/lua/megacity_spec.lua` runs "only the districts near a ship are solid, built there and then if need be", "at most nine districts per player and sixteen in all are solid, nearest first" and "streaming districts in and out keeps the game deterministic across save and restore", and `tests/game/megacity.lua` runs
- **THEN** they pass

### Requirement: Megacity detail levels
The view SHALL draw an outer district as its full mesh with lit window bands within 4 km, as a lit silhouette within
40 km, and SHALL draw a horizon band of far towers round the city. Meshes SHALL be built ahead of the eye within a
per-frame budget (6 ms, 4 ms on the web) and freed when far. Over a megacity the far plane SHALL reach the band, the
city's air and light SHALL hold over its whole footprint, and the sky's backdrop sprites SHALL be drawn behind every tower.

#### Scenario: Levels
- **WHEN** `tests/lua/megacity_spec.lua` runs "the view draws full blocks and lit windows near, silhouettes far and a horizon band beyond" and "over an outer district the city's air and light hold, and the frame draws the megacity"
- **THEN** both pass

### Requirement: Organ halls
Every outer district whose ordinary megaforms allow it SHALL have an organ: its tallest ordinary megaform, hollow at the
street, with a hall 60-110 m high behind a ship-sized mouth in the face nearest the avenue, nothing solid inside the hall,
4-6 finds on its floor and a machine turning slowly in it whose halo spans most of the hall, every ring inside it. The finds SHALL be beamed like any other find and stay taken for
that player across a restore and a save.

#### Scenario: Organs
- **WHEN** `tests/lua/megacity_spec.lua` runs "every outer district's organ is hollow at the street: a hall behind a mouth, its finds inside" and "an organ's finds are beamed like any other and stay taken for that player", and `tests/game/megacity.lua` runs
- **THEN** they pass

### Requirement: Drifters
The outer avenues SHALL carry drifters: glowing slabs gliding back and forth down the avenue on a district's east and
south sides, turning and bobbing, render only, a function of the clock, never leaving the avenue.

#### Scenario: Drifters
- **WHEN** `tests/lua/megacity_spec.lua` runs "an organ's finds are beamed like any other and stay taken for that player"
- **THEN** it passes, the drifters staying inside the district's cell above the street

### Requirement: Terrace fold bays
An outer district SHALL have up to two fold bays on its tier tops at least 40 m above the street: a 44 x 44 m pad with
30 m of open air over it and a cradle on it, collided as drawn. A Villa growing back from the Seat in a bay SHALL pay
nothing, as in a relic's cradle bay.

#### Scenario: Bays
- **WHEN** `tests/lua/megacity_spec.lua` runs "the terraces hold fold bays with cradles, and growing back to the Villa in one is free"
- **THEN** it passes

### Requirement: The undercity
Under every organ that has room, a shaft SHALL drop from the back of its hall through the foundation into a warren: a
hub, two to four corridors out to chambers inside the district, walled and floored, the farthest chamber a sanctum
where glowing stones circle a breathing heart. The warren's finds SHALL be sensed only from inside it and stay taken
like the hall's.

#### Scenario: Warrens
- **WHEN** `tests/lua/megacity_spec.lua` runs "under each organ a shaft drops into a warren of corridors and chambers, its sanctum's finds beamed only from below", and `tests/game/megacity.lua` runs
- **THEN** they pass
