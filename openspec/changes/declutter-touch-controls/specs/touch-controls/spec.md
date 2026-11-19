## ADDED Requirements

### Requirement: Touch action tray
The touch layout SHALL keep the move stick, the lift slider, USE and boost on screen at all times and SHALL have a MORE button that opens a tray holding every touch action (map, scan, decoy, jam, shrink, grow, grapple, beam, boost and Use). The tray SHALL lie inside the screen and the safe area, its buttons SHALL be at least 48 px, picking an action SHALL close it, and a tap outside it SHALL close it without acting.

#### Scenario: Open the tray and pick
- **WHEN** MORE is tapped and then the tray's MAP button is tapped
- **THEN** the map action fires and the tray closes

#### Scenario: Every action is in reach
- **WHEN** the tray is open at any of the eight reference sizes
- **THEN** every action has a shown tray button inside the tray, none overlap, and the tray is inside the safe area

### Requirement: Context buttons
The touch layout SHALL show the beam, grapple, jam, decoy, shrink and grow buttons only while they would act, in fixed slots: a hidden slot SHALL stay empty rather than let others move, and no context button SHALL be shown while a menu panel is open.

#### Scenario: Beam lined up
- **WHEN** the scanner locks a piece of loot at the helm
- **THEN** the BM button is shown in its slot

#### Scenario: No room to grow
- **WHEN** the saucer cannot grow where it is
- **THEN** the +SZ button is hidden and its slot stays empty

### Requirement: Context button conditions
The beam SHALL show when a target is locked, at the beam console or while the beam pulls; the grapple on foot on an excursion; the jammer while a sentry alarm is on or the saucer is clamped; a decoy under the same condition with decoys in stock outside home; shrink and grow at the helm or on foot when the size change would go through.

#### Scenario: Grapple on foot
- **WHEN** the player steps out onto a derelict
- **THEN** the GRP button is shown, and it is hidden again back at the helm

#### Scenario: Sentry
- **WHEN** a sentry alarm goes off with decoys in stock away from home
- **THEN** the JAM and DEC buttons are shown

### Requirement: Stable, visible changes under the thumb
A context button SHALL NOT appear, disappear or move under a finger that is pressing that slot or resting within its touch slop; the change SHALL wait until the finger lifts. A newly shown button SHALL fade in over about 150 ms with a short highlight pulse.

#### Scenario: Finger on the slot
- **WHEN** a finger holds a slot and its button's condition changes
- **THEN** the slot keeps its state until the finger lifts, then the button fades in with a pulse
