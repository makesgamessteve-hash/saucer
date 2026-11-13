## ADDED Requirements

### Requirement: Virtual controls on touch screens
The web build SHALL show on-screen controls when the player touches the screen: a move stick, a look area, a lift slider and buttons for shrink, grow, tractor, scan, door and boost, mapped through the same action map as every other device.

#### Scenario: Touch stick flies the saucer
- **WHEN** a finger pushes the virtual stick upward for one second
- **THEN** the saucer moves forward and the device mode reports `touch`

#### Scenario: Touch size button
- **WHEN** the shrink button is tapped while the Villa is in open space
- **THEN** the saucer shrinks to the Cruiser

### Requirement: Auto-hover
Releasing the lift slider SHALL hold the current altitude rather than drop the saucer.

#### Scenario: Release the slider
- **WHEN** the lift slider is released
- **THEN** the lift axis returns to 0 on the next command frame
