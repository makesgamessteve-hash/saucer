## ADDED Requirements

### Requirement: Light in the air
A few of a view's lights SHALL glow in the air: a point light as a soft halo, a spot as a visible cone, accumulated along the eye ray and ending at the first surface so walls cut the beams. The sun SHALL never glow. The high preset SHALL allow 4 glowing lights, low 2 with a cheaper cone, off none; a three or four way split screen SHALL allow at most 2.

#### Scenario: Headlight beams
- **WHEN** the headlights are on in a dark derelict hall on the high preset
- **THEN** at least one glowing light is reported for the view and the beams show in the air

#### Scenario: Off preset
- **WHEN** the shadow preset is off
- **THEN** no light glows in the air

### Requirement: Dark interiors
Inside a derelict, its lamps SHALL light pools with darkness between them and some rooms SHALL have no lamp, so the saucer's headlights and floods are needed to see; a city's rooms SHALL all have lamps. Every placed lamp SHALL be scaled by one global dimmer; the saucer's cabin lamps SHALL not be dimmed.

#### Scenario: A dark room
- **WHEN** the lamps of a sector's derelicts are generated
- **THEN** at least one room has no lamp and most rooms have one to three

#### Scenario: Floods to orient
- **WHEN** the floods are switched on inside a dark hall
- **THEN** an all-round saucer light lights the room around the saucer
