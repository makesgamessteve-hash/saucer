## MODIFIED Requirements

### Requirement: Grow requires clearance
Growing SHALL be refused, at no cost, if the target hull volume plus a 0.5 m margin intersects static geometry, and the HUD SHALL show the target hull as a red ghost. Unfolding back to the Villa SHALL cost half the fold cost (10 Charge) when it succeeds, except in a relic's cradle bay, where it SHALL cost no Charge; a Villa-sized saucer resting in a cradle bay SHALL regenerate 1 Charge per second.

#### Scenario: Blocked grow in a duct
- **WHEN** the saucer is Seat inside a duct and the player selects Villa
- **THEN** the grow is refused, Charge is unchanged, and a red Villa ghost is shown

#### Scenario: Free regrow in a cradle bay
- **WHEN** `tests/lua/relic_spec.lua` runs "lets ship.request grow for free" and `tests/game/relic.lua` regrows in a cradle bay and outside one
- **THEN** the cradle regrow costs nothing, the hall regrow costs 10 Charge, and a resting Villa gains about 2 Charge in 2 s
