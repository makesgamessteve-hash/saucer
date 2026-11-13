## ADDED Requirements

### Requirement: Size configurations
The saucer SHALL support Villa (XL), Cruiser (L), Pod (M), and Seat (S) configurations with the hull dimensions, stat multipliers, and Charge costs defined in Lua data (`data/base/saucer/configs.lua`).

#### Scenario: Data-driven sizes
- **WHEN** a mod changes Pod's hull diameter to 5 m
- **THEN** clearance checks and collision use 5 m for Pod

### Requirement: Shrink always succeeds with Charge
Shrinking SHALL succeed whenever the saucer has enough Charge and isn't clamped. It SHALL complete in 0.6 s, with shields disabled and collision damage ignored during the transition.

#### Scenario: Shrink in tight space
- **WHEN** the saucer is Villa with 50 Charge and the player selects Seat
- **THEN** the saucer becomes Seat after 0.6 s and Charge drops by 30 (5+10+15)

#### Scenario: Not enough Charge
- **WHEN** Charge is 3 and the player selects Cruiser from Villa
- **THEN** the transition is refused and the HUD shows "Not enough Charge"

### Requirement: Grow requires clearance
Growing SHALL be refused, at no cost, if the target hull volume plus a 0.5 m margin intersects static geometry, and the HUD SHALL show the target hull as a red ghost.

#### Scenario: Blocked grow in a duct
- **WHEN** the saucer is Seat inside a 2.5 m duct and the player selects Pod (4 m)
- **THEN** the grow is refused, Charge is unchanged, and a red Pod ghost is shown

### Requirement: Interior folding
Interior rooms SHALL be accessible only in the configurations that include them, and their contents SHALL persist through any sequence of transitions.

#### Scenario: Lab unavailable at Pod
- **WHEN** the saucer is Pod
- **THEN** the lab bench can't be used, and its queued identifications pause until the saucer is Cruiser or Villa again

### Requirement: Tractor size limit
The tractor SHALL only pick up items whose size class is at most the current configuration's tractor class, and the hold SHALL keep the same total capacity at all sizes.

#### Scenario: Item too big
- **WHEN** the saucer is Seat (S) and targets an M-class item
- **THEN** pickup is refused with the hint "Grow to Pod to lift this"
