## ADDED Requirements

### Requirement: Two sizes, Villa and Seat
The saucer SHALL have two configurations defined in `data/base/saucer/configs.lua`: the Villa (class 4, 26 × 12 m, the walkable interior) and the Seat (class 1, 1.8 × 1.4 m, one seat under a canopy). Folding to the Seat SHALL cost 20 Charge and unfolding half that. Cruiser, Pod and Pocket are not part of the base game.

#### Scenario: Fold down and back
- **WHEN** the Villa with 100 Charge folds to the Seat and later unfolds in open space
- **THEN** the Seat uses its own 1.8 m hull for collision at once, and Charge ends at 70 before regeneration

### Requirement: Unfolding needs room
Unfolding SHALL be refused at no cost when the Villa's hull around the pilot's eye plus a 0.5 m margin would intersect static geometry or another player's saucer, and the HUD SHALL show a red ghost Villa where it was asked to unfold.

#### Scenario: Blocked in a duct
- **WHEN** the Seat is inside a duct and the player asks for the Villa
- **THEN** the request is refused with "No room to grow here", Charge is unchanged and a red ghost is shown

### Requirement: No flight while reconfiguring
Flight input SHALL be ignored while the saucer reconfigures (0.9 s folding, 1.2 s unfolding), and Charge SHALL NOT regenerate during it.

#### Scenario: Busy
- **WHEN** the player asks for another size during a reconfiguration
- **THEN** the request is refused as busy
