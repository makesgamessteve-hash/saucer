## ADDED Requirements

### Requirement: Villa interior detail
The Villa interior SHALL include decor props in every room, railings with balusters, stair nosings and handrails, dome struts, floor trim and ceiling ribs. Decor SHALL be visual only and SHALL NOT add collision boxes.

#### Scenario: Decor never blocks walking
- **WHEN** the Villa interior is built
- **THEN** every decor kind has a builder, decor meshes appear in the room groups, and the collision boxes are the same as without decor

### Requirement: Moving engine machinery
The engine room SHALL show rotors and pistons that move with the render tick while the engine room is visible. The motion SHALL NOT affect the simulation.

#### Scenario: Engine parts move
- **WHEN** the engine parts are drawn at two different ticks
- **THEN** the rotor angles and piston heights differ

### Requirement: Hull detail and saucer LOD
The saucer hull SHALL have seams, lights, antennas and thrusters with a glow. Saucers further than the saucer LOD distance from the camera SHALL skip drawing their interior rooms.

#### Scenario: A far saucer
- **WHEN** another saucer is further away than the saucer LOD distance
- **THEN** its hull is drawn and its rooms are not
