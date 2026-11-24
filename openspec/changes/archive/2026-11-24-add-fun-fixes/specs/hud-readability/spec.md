## ADDED Requirements

### Requirement: Text plates
Every HUD text line SHALL be drawn on a dark plate (black, 80 % opacity) so that text keeps a contrast of at least 3.5:1 over a bright scene. Faint text (under 30 % opacity) SHALL have no plate.

#### Scenario: Bright scene
- **WHEN** the HUD draws a message over a lit derelict wall
- **THEN** a dark plate sits behind the message's text

### Requirement: Hit feedback
A hit on the player's hull SHALL frame the view in red for 9 ticks, fading, and, outside XR, shake the camera by up to 0.02 rad scaled by trauma squared and hold the camera pose for 3 ticks (50 ms). None of this SHALL change the simulation.

#### Scenario: Bolt hit
- **WHEN** a Watcher bolt hits the Villa
- **THEN** the view flashes a red frame, the camera holds for 50 ms and then shakes briefly, and the replay hash is the same with the view on or off
