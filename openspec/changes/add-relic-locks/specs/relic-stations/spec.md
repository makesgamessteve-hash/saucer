## ADDED Requirements

### Requirement: Relic foot pockets
A relic in play SHALL have 1-3 foot pockets, set by its builders' body scale (tiny 3, human and large 2, giant and colossal 1, others 2). Each pocket SHALL open off a Seat chamber, never a hall, the heart or the main route. A crawlspace 8-28 m long with a 1 x 1 m channel SHALL lead to an 8 x 4 x 8 m pocket room, and the walk from the chamber floor into the room SHALL be at most 60 m.

#### Scenario: Pockets by body scale and place
- **WHEN** `tests/lua/relicfoot_spec.lua` runs "counts pockets by the builders' body scale", "opens pockets off Seat chambers only, never the route, a hall or the heart" and "keeps every pocket a short walk down a channel no saucer fits"
- **THEN** all pass

### Requirement: Relic pockets derived from the seed
A relic's pockets and extra locks SHALL be derived from the seed on a copy of the generated relic, once per generated ruin, and SHALL never be saved; the generated ruin SHALL stay as generated.

#### Scenario: Derived once
- **WHEN** `tests/lua/relicfoot_spec.lua` runs "derives once per generated ruin and leaves the generated ruin as it was"
- **THEN** it passes

### Requirement: Relic lock mix
A relic's hand-lock SHALL seal the richest Seat chamber holding at most 15% of the relic's value, and SHALL sit in the first pocket. There SHALL be at most one hand-lock. One or two more chambers SHALL get Seat-locks, so that with the reliquary's Seat-lock 60-75% of the locks are Seat-locks. Snatcher nests SHALL never be sealed, and neither the main route nor the heart SHALL ever need a lock turned on foot.

#### Scenario: Value and share
- **WHEN** `tests/lua/relicfoot_spec.lua` runs "seals at most 15% of the value behind the hand-lock and keeps 60-75% Seat-locks"
- **THEN** it passes

#### Scenario: Turning the hand-lock on foot
- **WHEN** `tests/game/relic_locks.lua` runs (CTest `game_relic_locks`, `game_relic_locks_seed7`): it sets the Seat down on a chamber's ledge, steps out, crawls through, stands up in the pocket room and turns the hand-lock
- **THEN** the sealed chamber's shutter stops being solid, the chamber Seat-locks stay shut, and the player boards the Seat again
