## MODIFIED Requirements

### Requirement: Virtual controls on touch screens
The web build SHALL show on-screen controls when the player touches the screen: a move stick, a look area, a lift slider and buttons for shrink, grow, tractor, scan, Use and boost, mapped through the same action map as every other device. On the web the image SHALL fill the window, and the controls SHALL be laid out in CSS pixels from the shorter window side and redone when the window is resized or rotated.

#### Scenario: Button sizes and spacing
- **WHEN** the controls are laid out on any window size
- **THEN** every button is at least 44 px (48 px on phones) with gaps of at least 8 px, inside the safe area

#### Scenario: Touch stick flies the saucer
- **WHEN** a finger pushes the virtual stick upward for one second
- **THEN** the saucer moves forward and the device mode reports `touch`

#### Scenario: Touch size button
- **WHEN** the shrink button is tapped while the Villa is in open space
- **THEN** the saucer folds to the Seat

#### Scenario: A small phone in portrait
- **WHEN** the controls are laid out for a 320x568 window with a 16 px bottom safe area
- **THEN** every button is at least 48 px, no two controls are closer than 8 px, and none is in the safe area or over the crosshair or status block

#### Scenario: Rotation
- **WHEN** a 390x844 window turns into 844x390
- **THEN** the controls are laid out again for landscape and fingers still hit the controls where they are drawn

### Requirement: Forgiving, readable touch controls
A finger that lands just outside a button (within half a gap) SHALL press it in preference to the look area. Held widgets SHALL be highlighted, labels SHALL fit their buttons, the stick SHALL float where the thumb lands, ignore a small radial deadzone and follow the thumb past its rim, a stick or slider SHALL be owned by one finger with a second finger there looking instead, and pressing a button SHALL request a short vibration on the web.

#### Scenario: A near miss
- **WHEN** a finger lands just above the USE button
- **THEN** USE is pressed, the widget reports held and a vibration is requested

#### Scenario: The floating stick
- **WHEN** a thumb lands on the stick area and moves
- **THEN** the touch layout reports the start and current points of the stick

#### Scenario: Deadzone and follow
- **WHEN** a thumb on the stick moves less than the deadzone, then far past the rim
- **THEN** the stick reads zero, then full deflection with its base moved toward the thumb

## ADDED Requirements

### Requirement: HUD clear of the touch controls
With touch controls showing, the HUD's text and panels SHALL NOT draw over a control: centred text SHALL be clipped to the span between the controls on its row, the message log and the context hint SHALL be stacked in a clear column, and the title card SHALL be placed or narrowed to stay clear. A menu entry too long for its narrowed panel SHALL wrap onto more lines rather than be cut off, and a centred line too wide for the span between the controls SHALL break at its parts.

#### Scenario: The HUD at the reference sizes
- **WHEN** the walk and helm HUD are drawn with touch controls at 320x568, 360x640, 390x844 and 768x1024 and their landscape versions
- **THEN** no HUD text or panel overlaps a control and the log lines sit in the clear column

#### Scenario: Title menu on a small phone
- **WHEN** the title menu is shown with touch controls at 320x568 or any other reference size, portrait or landscape
- **THEN** every entry ("Load saved game", "Comfort settings", ...) and the "STICK UP/DOWN" / "USE: PICK" line are shown in full and on screen

#### Scenario: Hint over the log
- **WHEN** the context hint shows on a touch screen
- **THEN** it is stacked above the log inside the clear column and overlaps no other text

### Requirement: Touch control states
Touch buttons SHALL show when they are pressed (filled, outlined twice, label nudged), when their effect is on (the tractor beam), when they are cooling down (a draining fill and the seconds left) and when they are unavailable (no decoys left); the lift slider SHALL read the altitude at the helm.

#### Scenario: Cooldown
- **WHEN** the scanner has 150 ticks of cooldown left
- **THEN** the SCN button shows a draining fill and "3S"

### Requirement: No browser gestures over the game
The web page SHALL NOT pull to refresh, zoom, scroll, select text or open a context menu from touches on the game, and SHALL keep its panels clear of the safe areas.

#### Scenario: Pinch on the game
- **WHEN** two fingers pinch on the canvas
- **THEN** the page does not zoom and the game receives both fingers
