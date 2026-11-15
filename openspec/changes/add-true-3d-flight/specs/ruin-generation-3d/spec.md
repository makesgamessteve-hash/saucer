## ADDED Requirements

### Requirement: Rooms grow in all six directions
The generator SHALL attach rooms on all six faces of a parent. Side doors SHALL sit on the higher of the two floors. Floor and ceiling hatches SHALL join rooms on different levels, and shafts SHALL rise or drop several levels. Every room SHALL stay reachable for its size class.

#### Scenario: Multi-level layouts
- **WHEN** 20 seeds are generated for each of the starship, station and city kits
- **THEN** none falls back, every layout meets its kit's span and level minimums, and they contain hatches, shafts, and rooms both above and below the entrance

### Requirement: Minimum height per kit
Each kit SHALL set its grid, its minimum vertical span and its minimum number of levels. A layout below those minimums SHALL be retried, up to 8 tries. After that, a hand-placed three-level layout (hall, a shaft up its ceiling, a duct vault) SHALL be used.

#### Scenario: Fallback still climbs
- **WHEN** every try fails
- **THEN** the fixed layout has a shaft above the hall through a ceiling hatch and a duct vault that needs the Seat

### Requirement: Huge sites
Exterior solids SHALL be added around the rooms: hull spines on ships, trusses on stations, and towers above and below cities. They SHALL never overlap a room or block a door. A site SHALL span well over 100 m on every axis, and the sector SHALL place its sites at different heights.

#### Scenario: Size of a site
- **WHEN** a site of any kit is generated
- **THEN** its bounds exceed 120 m in x, y and z, and its solids overlap no room

### Requirement: Deterministic, cached generation
Generation SHALL be a pure function of the seed, kit, civilization, origin and entrance class. Results MAY be memoized. Committed layout known answers (the hash and the room, wall and solid counts) SHALL be reproduced on every platform.

#### Scenario: Known answers
- **WHEN** the layout specs run on linux-gcc, linux-clang, windows-msvc and emscripten
- **THEN** every committed layout hash and count matches
