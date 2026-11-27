## ADDED Requirements

### Requirement: Generated planet bodies
A body city (a planet, a moon or an asteroid) SHALL sit on a seeded sphere derived from the city's seed, the street tangent to the sphere, with a rim around the megacity flattened so the lots sit flush.

#### Scenario: a body city sits on a seeded sphere, the street tangent to it
- **WHEN** `tests/lua/planet_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the same city seed always makes the same body
- **WHEN** `tests/lua/planet_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Planet-like surface by body
The body's surface SHALL read from space and around the city: oceans and land on a planet, maria and craters on a moon, lumpy rock on an asteroid.

#### Scenario: a planet has land and ocean, a moon has craters, an asteroid is rock
- **WHEN** `tests/lua/planet_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Sector heart stays in space
The sector's other sites, the trader station and the arrival point SHALL stay in open space in a bay toward the origin. The body SHALL wrap the sides and the far side of the city.

#### Scenario: the sector heart stays in open space, the body wraps the city's far side
- **WHEN** `tests/lua/planet_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Drawn globe and terrain
The body SHALL be drawn as a smooth spherical globe and a smooth-shaded terrain cap around the city, behind the city and in front of the stars. Land and ocean on the globe SHALL come from continuous 3D noise (not a tile grid) and be lit by the sector sun with a day/night terminator. A planet SHALL have a faint atmosphere, brighter on the lit side. The camera-locked sky planet billboard SHALL be hidden in a sector that already has a planet body.

#### Scenario: a globe and a terrain cap are built and drawn for a body city
- **WHEN** `tests/lua/planet_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: from a sector with a planet city the body is drawn and the sky billboard is hidden
- **WHEN** `tests/lua/planet_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a moon keeps the sky's distant planet; a planet city hides it
- **WHEN** `tests/lua/planet_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Air, landing and collision
The body's air SHALL hold over the cap. The surface outside the city rim SHALL be landable, and the hull SHALL not sink through it. Under the city the existing lots and the warren SHALL be unchanged.

#### Scenario: the hull lands on and will not sink through the body's surface
- **WHEN** `tests/lua/planet_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Concentric city layout
A body city SHALL be planned as a big centre with a plaza and a landmark spire, then ring-districts outward (civic, market, residential, industrial and a spaceport on the outer ring), each ring with its own building mix and silhouette. Curved ring roads and radial avenues SHALL make the plan readable from the air. The core footprint SHALL be a disk, not a square.

#### Scenario: a city is concentric: a big core and rings of different districts
- **WHEN** `tests/lua/city_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Annular megacity
The megacity's outer districts SHALL stand in an annulus around the circular core, clear of the core and of the sector heart.

#### Scenario: a city's core is ringed by outer districts, 24 to 48 districts in all
- **WHEN** `tests/lua/megacity_spec.lua` runs its scenario of this name
- **THEN** it passes
