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

### Requirement: Touch look turns by an angle
A look drag on a touch screen SHALL turn the view by an angle, not a turn rate, on its own command axes (`aim_yaw`, `aim_pitch`): per tick `d / short × 210° × sensitivity × accel(d / short)`, with `d` the thumb travel and `short` the image's shorter side, both in CSS px, and `accel(v) = clamp(1 + 6·(v − 0.025), 0.85, 1.6)`. Half the short side in a quarter second SHALL turn 90–120 degrees at the default sensitivity.

#### Scenario: Half the short side
- **WHEN** a look finger moves across half the short side over 15 ticks, at any of the eight reference sizes and at a pixel ratio of 1, 2 or 3
- **THEN** the view turns between 90 and 120 degrees, the same at every size and ratio

#### Scenario: A flick turns further
- **WHEN** the same distance is swiped in 5 ticks instead of 15, or dragged over 120
- **THEN** the flick turns further and the slow drag less

### Requirement: Touch look speed setting
The comfort settings SHALL have a touch look speed from 0.5x to 2x in steps of 0.25 (default 1x) that scales the look angle, is saved in `comfort.txt` as `look_sens` and is loaded at start.

#### Scenario: Saved and applied
- **WHEN** the look speed is set to 0.5x and the game restarts with the same user directory
- **THEN** the setting is 0.5x and a swipe turns half as far as at 1x
