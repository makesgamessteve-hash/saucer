## ADDED Requirements

### Requirement: Guest home-life in a host's Villa
While a guest is walking a docked host's Villa, Use at a home-life station SHALL act on the host's house state and open the panel for the guest. Use with nothing else in reach SHALL still open the gift table. The guest's command frames SHALL be ordinary lockstep frames.

#### Scenario: A guest cooks nothing at a host stove and is not thrown out
- **WHEN** `tests/lua/homeedit_spec.lua` runs its scenario of this name
- **THEN** it passes
