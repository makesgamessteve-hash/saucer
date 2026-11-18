## ADDED Requirements

### Requirement: Mystery from the universe seed
The central mystery (cause, cast, clue graph, host sites, Echo IDs) SHALL be a pure function of the universe seed and mod set, generated from Lua templates.

#### Scenario: Same seed, same mystery
- **WHEN** universe `SAUCER01` is created twice
- **THEN** the cause, the clue DAG, and the host site of every Echo are identical

### Requirement: Clue placement is reachable
Each Echo SHALL be placed in an archive room of its host site's ruin, and ruin validation SHALL guarantee the room is reachable.

#### Scenario: Property test
- **WHEN** 500 universe seeds are generated in CI
- **THEN** every Echo's archive room passes reachability validation

### Requirement: Decoding unlocks the chain
Decoding an Echo at the lab bench SHALL reveal its generated text and mark the next node's host site as Resonant on the map once that node's prerequisites are met.

#### Scenario: MVP chain
- **WHEN** the player decodes the Who and Where Echoes, then recovers the Key
- **THEN** the Resonant vault opens and contains the unique mystery Curio

### Requirement: Optional mystery
The mystery SHALL be configurable at universe creation as On, Hints, or Off. When Off, no Echoes or Resonant markers SHALL be generated, and no other system SHALL change.

#### Scenario: Sandbox only
- **WHEN** a universe is created with Mystery Off
- **THEN** no archive rooms, Echoes, or Resonant markers exist, and sites, traders, and prices are generated normally
