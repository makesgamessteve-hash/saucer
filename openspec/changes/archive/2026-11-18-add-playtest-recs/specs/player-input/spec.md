## ADDED Requirements

### Requirement: Grapple key
The grapple SHALL have its own action, bound to Y, the gamepad D-pad up, the right-half keyboard's 0 and the touch GRP button, appended after every existing action so earlier action slots keep their order. The Shroud key on foot SHALL only say what it is and SHALL NOT fire the grapple.

#### Scenario: Grapple on foot
- **WHEN** a player on foot in a derelict presses the grapple action
- **THEN** the grapple fires, and pressing the Shroud key instead does not fire it
