# audio-presentation Specification

## Purpose
Looping voices, event sounds and ambience that follow what the player is doing.

## Requirements

### Requirement: Looping voices
`saucer.audio.play(path, {loop = true})` SHALL return a handle for a voice that repeats until `saucer.audio.stop(handle)`. `saucer.audio.set(handle, {volume = v})` SHALL change its volume.

#### Scenario: Start, change and stop a loop
- **WHEN** a script starts a loop, sets its volume and stops it
- **THEN** the loop is counted while it plays and is gone after the stop

### Requirement: Event sounds and ambience
The renderer SHALL play the sim's fx, door, panel-click and pocket-coin sounds, and SHALL keep an engine hum, beam, holodeck, station and derelict loop at levels that follow what the player is doing, fading between them. Audio SHALL NOT modify the simulation state.

#### Scenario: Loop levels
- **WHEN** the player flies fast at the helm with the beam on near a derelict
- **THEN** the engine, beam and derelict loops are up and the station loop is off

#### Scenario: Events
- **WHEN** a door starts to move, the panel selection changes and the saucer goes into the pocket between two frames
- **THEN** a door, click and coin sound are played
