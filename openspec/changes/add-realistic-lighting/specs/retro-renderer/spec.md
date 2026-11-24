## ADDED Requirements

### Requirement: Light sources
Each view SHALL be lit by a list of sun, point and spot lights submitted per frame, each with a colour and intensity; point and spot light SHALL fall off by the inverse square with a soft source and fade to nothing at their range. The ambient light SHALL stay low and the result SHALL be exposed and tonemapped. Up to 16 lights SHALL shade a view (8 on the low preset or in a three or four way split screen), the strongest at the eye first.

#### Scenario: A far lamp is dropped
- **WHEN** a point light lies more than 150 m beyond its range from the eye
- **THEN** it is not among the view's active lights

#### Scenario: A full list
- **WHEN** more than 96 lights are submitted to one view in a frame
- **THEN** the extra lights are counted as dropped and the frame still renders

### Requirement: The star is the light outside
Outside, each sector's star (its colour and direction fixed by the seed and the sector) SHALL be the first and dominant light and SHALL cast shadows through fitted cascades. Inside a derelict, a city, a station or a hangar bay no sunlight SHALL reach; only the place's own coloured lamps SHALL light it.

#### Scenario: Sun first
- **WHEN** the saucer hovers outside a derelict
- **THEN** the first active light is the sun and at least one shadow cascade is in use

#### Scenario: No sun inside
- **WHEN** the saucer is inside a derelict hall or the hangar bay
- **THEN** no sun is active and point lamps light the room

### Requirement: Shadow quality presets
Shadows SHALL be drawn into one depth atlas: sun cascades, spot maps and cube maps for the strongest point lights. Presets off, low and high SHALL set the atlas size and the number of maps (`--shadows`, `saucer.render.settings{shadows=}`), low being the default on the web. A three or four way split screen SHALL get one map of each kind.

#### Scenario: Shadows off
- **WHEN** the shadow preset is off
- **THEN** no shadow maps are drawn and the lights still shade the scene

#### Scenario: Four views
- **WHEN** four players share the screen on the high preset
- **THEN** each view uses at most one cascade, one spot map and one cube map
