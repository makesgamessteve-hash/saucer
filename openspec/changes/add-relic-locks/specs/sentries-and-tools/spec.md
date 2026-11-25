## ADDED Requirements

### Requirement: Guarded relic pockets
At most one foot pocket in a relic SHALL open off a Snatcher's nest chamber, and a nest chamber SHALL never be sealed by a lock, so a guarded find is always reachable in the Seat.

#### Scenario: One guarded pocket at most
- **WHEN** `tests/lua/relicfoot_spec.lua` runs "opens pockets off Seat chambers only, never the route, a hall or the heart" and "seals at most 15% of the value behind the hand-lock and keeps 60-75% Seat-locks"
- **THEN** both pass
