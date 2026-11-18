# touch-controls Specification

## Purpose
Touch screens get virtual controls with auto-hover that stay forgiving and readable.

## Requirements

### Requirement: Virtual controls on touch screens
The web build SHALL show on-screen controls when the player touches the screen: a move stick, a look area, a lift slider and buttons for shrink, grow, tractor, scan, Use and boost, mapped through the same action map as every other device.

#### Scenario: Touch stick flies the saucer
- **WHEN** a finger pushes the virtual stick upward for one second
- **THEN** the saucer moves forward and the device mode reports `touch`

#### Scenario: Touch size button
- **WHEN** the shrink button is tapped while the Villa is in open space
- **THEN** the saucer folds to the Seat

### Requirement: Auto-hover
Releasing the lift slider SHALL hold the current altitude rather than drop the saucer.

#### Scenario: Release the slider
- **WHEN** the lift slider is released
- **THEN** the lift axis returns to 0 on the next command frame

### Requirement: Forgiving, readable touch controls
A finger that lands just outside a button (within the touch slop) SHALL press it in preference to the look area. Held widgets SHALL be highlighted, labels SHALL fit their buttons, the stick SHALL show where the thumb landed and where it is, and pressing a button SHALL request a short vibration on the web.

#### Scenario: A near miss
- **WHEN** a finger lands just above the USE button
- **THEN** USE is pressed, the widget reports held and a vibration is requested

#### Scenario: The floating stick
- **WHEN** a thumb lands on the stick area and moves
- **THEN** the touch layout reports the start and current points of the stick

### Requirement: Grapple button
The touch layout SHALL have a GRP button for the grapple, before the look area.

#### Scenario: Touch layout
- **WHEN** the touch controls are laid out
- **THEN** a "grapple" button exists and drives the grapple action
