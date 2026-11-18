## ADDED Requirements

### Requirement: Deterministic items
An item's base type, tier, origin civ, affixes, and quirks SHALL be derived from `(site_seed, slot_index)`.

#### Scenario: Reload consistency
- **WHEN** a player saves before looting slot 7, reloads, and loots it
- **THEN** the item is identical to the one rolled before the reload

### Requirement: Identification
Unidentified items SHALL hide their affixes and quirks. The lab bench SHALL identify an item in `30 s × tier` of sim time, and installing an unidentified module SHALL apply its quirks immediately.

#### Scenario: Hidden quirk
- **WHEN** an unidentified "Unstable" module is installed
- **THEN** the Charge drain applies at once, and the HUD shows "Unknown effect"

### Requirement: Echoes are not sellable
Echo items SHALL be marked non-sellable and non-installable, and SHALL never be lost through a failure.

#### Scenario: Trade screen
- **WHEN** the player opens a trade screen holding an Echo
- **THEN** the Echo is listed as "Not for sale"
