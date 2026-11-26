## ADDED Requirements

### Requirement: Relic room shapes
A patterned relic's halls SHALL take non-box shapes its pattern calls for, solid outside the shape and drawn and
mapped along it. Every door SHALL keep a clear channel to the hall's centre, and loot, phenomena, sentries, cover
and lamps SHALL stay on free floor. The maw's hall, the lung, the plague hall, the heart and the Vyrr warren SHALL
keep their boxes.

#### Scenario: Every kind keeps clear channels
- **WHEN** `tests/lua/relicshape_spec.lua` runs "every kind keeps a shape inside its box, a clear centre and a clear channel from every door"
- **THEN** it passes

#### Scenario: Which halls are shaped
- **WHEN** `tests/lua/relicshape_spec.lua` runs "shapes every patterned relic's halls but the maw's, the lung and the plague hall; the warren keeps boxes"
- **THEN** it passes

#### Scenario: Shell and ring read differently
- **WHEN** `tests/lua/relicshape_spec.lua` runs "the shell reads round and the ring curved: different shapes, and different plans"
- **THEN** it passes

#### Scenario: The ways through stay clear
- **WHEN** `tests/lua/relicshape_spec.lua` runs "the autopilot's way into every shaped hall, loot and phenomena stay clear of the solid"
- **THEN** it passes

#### Scenario: Systems in play
- **WHEN** `tests/lua/relicshape_spec.lua` runs "in play: the solid collides, sentries, cover, finds and lamps sit on free floor, walls and map follow"
- **THEN** it passes

### Requirement: No two relics of a species alike
Every relic SHALL differ from every other relic of the same species in the same universe by at least
`relicsig.MIN_DIST` under the layout distance (1 - IoU of the top-down room plans without the heart, minimised over
turns and mirrors). The generator SHALL redraw a relic against its species' earlier relics until it does.

#### Scenario: The metric
- **WHEN** `tests/lua/relicunique_spec.lua` runs "measures alike up to a turn or a mirror, and apart when nothing overlaps"
- **THEN** it passes

#### Scenario: Redrawn when alike
- **WHEN** `tests/lua/relicunique_spec.lua` runs "a relic drawn against its own copy is drawn again, unlike it; no siblings leaves it as it is"
- **THEN** it passes

#### Scenario: Every relic in play
- **WHEN** `tests/lua/relicunique_spec.lua` runs "every relic in play is unlike every other relic of its species, in many universes"
- **THEN** it passes

#### Scenario: A run of stations per species
- **WHEN** `tests/lua/relicunique_spec.lua` runs "a run of stations of each species: all unlike each other"
- **THEN** it passes
