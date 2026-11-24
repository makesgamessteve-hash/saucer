## MODIFIED Requirements

### Requirement: Sliding doors
The bedroom and bathroom SHALL have doors that slide open while a player's body is on their deck within reach, and close otherwise. A door SHALL be solid while less than 75 % open and SHALL NOT turn solid under a body that overlaps it. A door SHALL decide with hysteresis and move toward its goal at a fixed speed, so a body near a door never makes it open and close repeatedly.

#### Scenario: Hysteresis
- **WHEN** a body stands or sways near a door
- **THEN** the door opens when the body comes within reach, only starts to close once every body is farther than the reach plus a close margin and a minimum open time has passed, and rests exactly on its goal

#### Scenario: Walking through the bedroom door
- **WHEN** the player walks up to the bedroom door, through it, and away
- **THEN** the bedroom door opens on approach, lets them through, and closes behind them

#### Scenario: Standing still beside an open door
- **WHEN** the player stands one meter from the open bedroom door for three seconds
- **THEN** the door stays exactly fully open and makes no sound

#### Scenario: Swaying on the trigger edge
- **WHEN** the player's body creeps back and forth across the door's reach for ten seconds
- **THEN** the door opens once and stays open, with no repeated direction reversals and no repeated collision changes

#### Scenario: Not solid under a body
- **WHEN** a closed door's box overlaps a body
- **THEN** the door is not among the solids until the body is out
