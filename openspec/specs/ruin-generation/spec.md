# ruin-generation Specification

## Purpose
Ruins are generated from modular kits into size-gated, reachable mission graphs within a generation budget.

## Requirements

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

### Requirement: Derelicts big enough for the Villa
Ruins SHALL be built at a scale where the Villa flies inside: a chain of great halls (class 4) from the entrance to the Vault, joined by Villa-sized doors, with ducts (class 1) branching off them that only the Seat fits through, sometimes leading to a chamber behind. Every room SHALL be reachable at its size class and its loot SHALL fit through the way in.

#### Scenario: Halls and ducts
- **WHEN** a starship derelict is generated for any seed
- **THEN** its entrance and great halls are class 4, at least one duct room is class 1, and the Vault is a great hall at the end of the chain
