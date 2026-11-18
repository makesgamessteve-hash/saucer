## ADDED Requirements

### Requirement: City generation
A city SHALL be generated from the site seed as a ruin-shaped table through `sim/citygen.lua`, hierarchically (districts, blocks, buildings, tunnels, an undercity), identically on every visit, inside a generation budget, with every room and loot slot reachable, a spaceport hangar as the entrance, one landmark district of each kind and a distinct form per body.

#### Scenario: a city is the same every visit and differs between seeds
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: every city validates: all rooms and every loot slot are reachable
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a city stays inside its generation budget
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a city is many kilometres of districts, blocks and buildings with towers to fly between
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the undercity lies in layers below the streets and tunnels join the buildings
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: every city has a spaceport hangar as its entrance and one landmark per district kind
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the reactor heart holds the vault and the rich landmarks pay better
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a planet city is tall and heavy, a moon city sits in a crater, an asteroid city in carved rock
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: sky-bridges join towers on a planet and a moon but not inside an asteroid
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the generation fails loudly rather than handing back a broken city
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: City sites
Sectors 2 to 4 SHALL each hold one city (one of each body) and later far sectors SHALL hold one by a seeded coin toss, as an extra site from its own seed stream so every other site, the home sector and every replay stay as they were. The sector map SHALL tag them and entering one SHALL say what it is.

#### Scenario: the three nearest far sectors hold one city of each body and sector 1 holds none
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a city site sits far out, clear of the other sites, in a sector's list
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the sector map tags the cities
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: entering a city says what it is and what the body does to the hull
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: District power grid
Every district but the spaceport SHALL start dark: shut gates and sleeping sentries, with a power coupling the belly beam lifts. Beaming it SHALL restore the district, open its gates and wake its sentries, and the grid SHALL persist in saves and across fold jumps. Calm halls SHALL keep no sentry.

#### Scenario: only the spaceport starts live; every other district has a coupling and shut gates
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a shut gate is solid until its district is restored
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: beaming a coupling home restores its district, opens its gates and tells the party
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a partner in the city is told who restored a district
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: restored power survives a save, a load, a fold away and a fold back
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a sentry in a dark district sleeps until the grid comes back, a calm hall keeps none
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the clamps, the lockdown node and the warden stay out of calm halls
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Body gravity
Hovering under a pull above 1 g (a planet city) SHALL cost Charge each second, the spaceport hangar SHALL be free and refill the Charge, and with no Charge the hull SHALL settle at a walking pace while horizontal flight stays free, so no hull is ever trapped. A moon's light pull and an asteroid's none SHALL cost nothing.

#### Scenario: hovering under a planet's pull costs Charge, the spaceport hangar refills it
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: with the Charge gone the hull settles at a walking pace and horizontal flight stays free
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a moon's light pull and an asteroid's none cost nothing
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: City navigation
Inside a city the map key SHALL open a city map (districts with their landmark, grid state, distance and compass direction, a plan with couplings and saucers, and the way back to the sector map) and the HUD SHALL name the body, the district and the grid and point a beacon at the nearest dark coupling, then at the reactor vault.

#### Scenario: the city map panel lists every district, its grid state and the way back to the sector map
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the beacon points at the nearest dark coupling, then at the reactor vault
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the HUD names the body, the district and the beacon; the city map draws districts, couplings and saucers
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: City loot
Only loot slots within beam sense of the saucer SHALL be rolled each tick so a city with hundreds of slots stays cheap, and the power couplings SHALL be tractor candidates.

#### Scenario: only the loot within beam sense is rolled, the couplings are beam targets
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: City rendering and environment
A city SHALL be drawn in streamed chunks: districts farther than a set distance as one coarse mesh each, nearer ones as their culled room and solid chunks with detail only close by, and the gates of dark districts as shutters. The air SHALL belong to the body: a planet fog with a day and night cycle, a moon in earthlight without air, an asteroid in dark rock.

#### Scenario: a far district is one coarse mesh, a near one its chunks, and every gate is drawn near it
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the air of a city belongs to its body: a planet has a day, a moon earthlight, an asteroid dark rock
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a city kit's detail style and texture come from the kit
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: A city can be restored end to end
A player SHALL be able to fly to a dark district's power coupling, beam it home from the Tractor Room console and see its gates open, and a planet city SHALL drain Charge under the full simulation.

#### Scenario: a moon city's coupling is beamed home and a planet city's pull drains Charge
- **WHEN** `tests/game/city.lua` (ctest `game_city`) folds into the moon and planet cities, flies to a coupling and beams it
- **THEN** the grid reads 2/9, the district's gates are open, the beacon moves on, and hovering in the planet city spent Charge
