## ADDED Requirements

### Requirement: Size configurations
The saucer SHALL have two configurations defined in Lua data (`data/base/saucer/configs.lua`): the Villa (class 4, 26 × 12 m, the walkable interior) and the Seat (class 1, 1.8 × 1.4 m, one seat under a canopy). Cruiser, Pod and Pocket are not part of the base game. Mods MAY add sizes through that data file.

#### Scenario: Data-driven sizes
- **WHEN** a mod changes the Seat's hull diameter to 2.4 m
- **THEN** clearance checks and collision use 2.4 m for the Seat

### Requirement: Shrink always succeeds with Charge
Shrinking SHALL succeed whenever the saucer has enough Charge and isn't clamped. It SHALL complete in 0.9 s, with shields disabled and collision damage ignored during the transition. Folding to the Seat SHALL cost 20 Charge.

#### Scenario: Shrink in tight space
- **WHEN** the saucer is Villa with 50 Charge and the player selects Seat
- **THEN** the saucer becomes Seat after 0.9 s and Charge drops by 20

#### Scenario: Not enough Charge
- **WHEN** Charge is 3 and the player selects Seat from Villa
- **THEN** the transition is refused and the HUD shows "Not enough Charge"

### Requirement: Grow requires clearance
Growing SHALL be refused, at no cost, if the target hull volume plus a 0.5 m margin intersects static geometry, and the HUD SHALL show the target hull as a red ghost. Unfolding back to the Villa SHALL cost half the fold cost (10 Charge) when it succeeds.

#### Scenario: Blocked grow in a duct
- **WHEN** the saucer is Seat inside a duct and the player selects Villa
- **THEN** the grow is refused, Charge is unchanged, and a red Villa ghost is shown

### Requirement: Interior folding
Interior rooms SHALL be accessible only while the saucer is the Villa, and their contents SHALL persist through any sequence of transitions.

#### Scenario: Lab unavailable in the Seat
- **WHEN** the saucer is the Seat
- **THEN** the lab bench can't be used, and its queued identifications pause until the saucer is the Villa again

### Requirement: Tractor size limit
The tractor SHALL only pick up items whose size class is at most the current configuration's tractor class, and the hold SHALL keep the same total capacity at all sizes.

#### Scenario: Item too big
- **WHEN** the saucer is Seat (S) and targets an M-class item
- **THEN** pickup is refused with the hint "Unfold the Villa to lift this"
