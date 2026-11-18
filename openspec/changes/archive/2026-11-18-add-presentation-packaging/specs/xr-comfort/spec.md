## ADDED Requirements

### Requirement: Snap turning
With snap turning on (the default), a right-stick flick past the snap threshold SHALL give exactly one snap turn of 30 degrees, and the stick SHALL re-arm only after it returns near the centre. With snap turning off, the stick SHALL turn smoothly. Snap turns SHALL be commands so replays stay deterministic.

#### Scenario: One flick, one snap
- **WHEN** the right stick is held fully right for ten ticks in a standing session
- **THEN** the body yaw changes by exactly -30 degrees

#### Scenario: Smooth turning
- **WHEN** snap turning is off and the stick is held right
- **THEN** the yaw keeps changing while it is held

### Requirement: Seated and standing sessions
A seated session SHALL use the `local` reference space with the headset origin at the cockpit eye. A standing session SHALL use `local-floor` and lower the cockpit by the eye height so the player's real height is used.

#### Scenario: Standing lowers the cockpit
- **WHEN** a camera is set up in a standing session and in a seated session
- **THEN** the standing camera is 1.62 m lower and the seated one is unchanged

### Requirement: Comfort vignette and diegetic controls
XR views SHALL draw a vignette whose strength follows the view's movement and smooth turning (not snap turns or cuts), scaled by the comfort setting. The flat HUD SHALL be off in XR, and tracked controllers SHALL be drawn as hands, with a wrist panel showing charge, hold and beam lock.

#### Scenario: Walking in VR
- **WHEN** the player walks forward in a standing session with tracked controllers
- **THEN** the frames draw the hands, the wrist panel and the vignette, and no HUD text
