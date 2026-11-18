## ADDED Requirements

### Requirement: Seed plus diffs
Saves SHALL store the universe seed, the mod set with versions, the player/saucer/hold/dome state, and per-site diffs, and SHALL NOT store generated geometry.

#### Scenario: Untouched universe
- **WHEN** a universe nobody has changed is saved
- **THEN** the save holds the seed, the mod set and the player records, and the world diff is empty

#### Scenario: Only changes are stored
- **WHEN** credits, a trader's demand, the vault and the clock have changed and the game is saved and loaded
- **THEN** the save holds those changes only, and the loaded universe has them over the regenerated sector, traders and requests

#### Scenario: Older save migrates
- **WHEN** a save in format 2 (full tables, state version 10) is loaded
- **THEN** it loads into the current game and the next save is written in the current format

#### Scenario: Mod set changed
- **WHEN** a save made with mod `bigger_ruins` is loaded without it
- **THEN** the player is warned that generation may differ and can cancel (closing the card loads nothing)

### Requirement: Atomic write
Saves SHALL be written to a temp file and atomically renamed (IndexedDB transaction on web).

#### Scenario: Crash during save
- **WHEN** the process is killed mid-write
- **THEN** the previous save loads intact

### Requirement: Player records
The universe save SHALL hold one player record per participant, keyed by `record_index` in join order (record 0 is the universe owner). Each record holds that player's saucer, hold, credits, archive, dome, and hot/banked state.

#### Scenario: Single-player compatibility
- **WHEN** a single-player save is loaded with `--local-players 2` in a test build
- **THEN** the existing record becomes record 0, unchanged, and a new record 1 is created with a starter saucer

#### Scenario: Records by join order
- **WHEN** a three-player universe is saved and loaded
- **THEN** the three records come back keyed by `record_index` 0, 1 and 2, each with its own saucer, hold, credits, archive, dome and hot/banked state
