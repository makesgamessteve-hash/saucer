## ADDED Requirements

### Requirement: Forgiving, readable touch controls
A finger that lands just outside a button (within the touch slop) SHALL press it in preference to the look area. Held widgets SHALL be highlighted, labels SHALL fit their buttons, the stick SHALL show where the thumb landed and where it is, and pressing a button SHALL request a short vibration on the web.

#### Scenario: A near miss
- **WHEN** a finger lands just above the USE button
- **THEN** USE is pressed, the widget reports held and a vibration is requested

#### Scenario: The floating stick
- **WHEN** a thumb lands on the stick area and moves
- **THEN** the touch layout reports the start and current points of the stick
