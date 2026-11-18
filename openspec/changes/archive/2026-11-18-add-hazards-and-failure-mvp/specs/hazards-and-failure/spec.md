## ADDED Requirements

### Requirement: The dome is safe
Damage volumes and hostile entities SHALL NOT affect the player while they're inside the dome interior, regardless of what's happening to the hull.

#### Scenario: Hull hit while walking the dome
- **WHEN** debris strikes the Villa hull while the player is at the lab bench
- **THEN** hull integrity drops, an alarm plays, and the player's Suit Charge and held items are unaffected

### Requirement: Hot and banked items
Items picked up at a site SHALL be *hot*, tracked per player, until that player leaves that site's boundary (its bounding volume plus 200 m), at which point they SHALL become *banked*. Banked items, installed modules, credits, and the dome SHALL NOT be lost through any failure on Standard or Cozy difficulty.

#### Scenario: Banking
- **WHEN** the player leaves a ruin's boundary carrying 2 hot items
- **THEN** both items are marked banked and are no longer eligible for loss

### Requirement: Fold Retreat
At zero hull, the saucer SHALL fold to the last visited trader, and all hot items SHALL drop as a recoverable cache at the point of failure.

#### Scenario: Hull destroyed in a ruin
- **WHEN** hull reaches 0 holding 3 hot items and 2 banked items
- **THEN** the saucer appears at the trader with the 2 banked items, a 3-item cache sits in the ruin, and it's marked on the site map

### Requirement: Non-lethal damage
No hazard or sentry SHALL reduce anything other than shields, hull, or Suit Charge, and none SHALL end the save on Cozy or Standard difficulty.

#### Scenario: Repeated failure
- **WHEN** the player triggers Fold Retreat 10 times in a row
- **THEN** the save remains playable, with all banked items intact
