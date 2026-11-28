## ADDED Requirements

### Requirement: State version 25 and a lazy home table
The state version SHALL be 25. House layout overrides, the undo stack and later home fields SHALL live in a `p.home` table created on first use. An in-progress edit carry (`p.edit`) SHALL NOT be saved; loading or saving SHALL put a carried piece back first. Seed-42 slice and co-op replays SHALL match version 25.

#### Scenario: A game that never edits has no p.home after a step
- **WHEN** `tests/lua/layout_spec.lua` runs its scenario of this name
- **THEN** it passes
