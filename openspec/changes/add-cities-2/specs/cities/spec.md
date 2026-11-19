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

### Requirement: Skyline ring
A city SHALL be surrounded by a ring of skyline districts, generated from their own seed child so the core is unchanged: only towers and blocks (collision boxes, no rooms, doors or slots), tens of districts and hundreds of boxes, all inside the site's bounds, so a planet city runs on for several kilometres and the sector keeps its other sites clear of it.

#### Scenario: a skyline ring of towers surrounds the core: tens of districts, hundreds of boxes, no rooms
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the ring does not change the core: the same rooms, doors and slots with or without it
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the ring is inside the site's bounds, so it is a place you can fly and crash into
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a city site sits clear of its sector's other sites however wide the ring
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Streamed skyline
The renderer SHALL draw each skyline district as one coarse mesh with a far glow, build the windows and lights of the districts near the camera one per frame, keep at most a handful built and free the oldest, and give a planet a ring of horizon impostors.

#### Scenario: skyline windows are built near the camera, a handful at a time, and the oldest are freed
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: near the ring its windows are drawn, far from it one coarse mesh per district, and a planet has a horizon
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Transit
A city SHALL have mag-rail lines on pylons across its whole width and one down its avenue, and a lift shaft at every plaza; the decks, pylons and shaft posts are solid, while the trains and lift cabins are drawn as a pure function of the tick, so nothing about them is stored.

#### Scenario: mag-rails run on pylons across the whole city and a lift stands at every plaza
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: trains and lift cabins are drawn from the clock: end to end and back, up and down
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Wet and wild undercity
The deep rooms and tunnels of a planet city SHALL hold water and canal lamps; the upper undercity of a planet or moon SHALL be overgrown with moss and vines; an asteroid's SHALL be bare rock.

#### Scenario: a flooded undercity holds water and canal lamps, an overgrown one moss and vines, a rock neither
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Storms and wind
A planet city SHALL be crossed by storm fronts on a fixed clock, with rain, thicker air, lightning and a wind that pushes a saucer in the open but not inside a room, and the HUD SHALL warn before a storm and during it.

#### Scenario: a storm front sweeps a planet city on a fixed clock, a moon has none
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the wind pushes a saucer in the open and does not reach it inside a room
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a storm darkens and thickens the air and lightning flashes it
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the HUD rains and warns of a storm before it and during it
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Falling bridges
Each sky-bridge of a planet city SHALL tear loose at the peak of one fixed storm, leave the physics, tell the players, and clip a hull at most once; the fall SHALL be drawn as a drop and replay the same after a rebuild.

#### Scenario: each sky-bridge tears loose at the peak of its storm, leaves the physics and tells the players
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a falling bridge clips a hull once: some hull lost, never more than once per bridge
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the falling bridge is drawn dropping and then gone, and is not in the far silhouette
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Dark patrols
Every dark district SHALL be patrolled by a roaming Watcher on a fixed route through its streets, drawn at a position that is a function of the tick; it SHALL go dormant when the district's grid is restored.

#### Scenario: a Watcher patrols the streets of every dark district and goes home when its grid is back
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Archive records
Each archive district SHALL hold one record in its ground hall, readable by the beam once the district's grid is up, taking no hold slot; it SHALL say where the next unlocked Echo waits (sector too, when elsewhere), then the Heart's sector, then lore of the cause, or a plain line when the mystery is off.

#### Scenario: every archive district holds one record in its ground hall, readable once its grid is up
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: reading a record names the next Echo, a later record the one after, and never fills the hold
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a record is a beam target when the hold is full and is drawn like an Echo
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: City outposts
A sector with a city SHALL hold a second trader, an outpost off the city's spaceport mouth, with its own demand ledger; docking there SHALL say so, and both stations SHALL be drawn and on the radar.

#### Scenario: a city sector has a trader outpost off its spaceport mouth, a pure function of the seed
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: docking at an outpost sells there with its own ledger, and says so
- **WHEN** `tests/lua/city2_spec.lua` runs its scenario of this name
- **THEN** it passes
