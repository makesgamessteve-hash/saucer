## ADDED Requirements

### Requirement: Kit-based modular ruins
Ruins SHALL be assembled from kit modules on a 4 m grid, connected through typed sockets (XL/L/M/S/F), with no overlapping module volumes.

#### Scenario: Socket compatibility
- **WHEN** a corridor module with an M socket is placed
- **THEN** it only connects to sockets of class M, or a size-transition module that steps M to S or L

### Requirement: Size-gated mission graph
Each ruin SHALL be generated from a mission graph containing at least one size lock and, in kits that support it, at least one hand lock on the critical path to the Vault.

#### Scenario: MVP starship
- **WHEN** a starship ruin is generated from any seed
- **THEN** reaching its Vault requires at least one shrink below the entry size

### Requirement: Reachability validation
After generation, every loot slot and the Vault SHALL be reachable by some sequence of moves, size transitions, and on-foot segments, given the abilities available at MVP. Otherwise the generator SHALL retry with derived seeds up to 8 times and then use the fallback layout.

#### Scenario: Property test
- **WHEN** 500 seeds are generated in CI
- **THEN** all pass validation without using the fallback layout

### Requirement: Generation budget
Ruin generation SHALL finish within 50 ms (desktop) and 200 ms (web) for ruins of up to 30 rooms.

#### Scenario: Budget check
- **WHEN** the nightly job generates 10,000 ruins
- **THEN** the 99th-percentile generation time is within budget
