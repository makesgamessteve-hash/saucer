## ADDED Requirements

### Requirement: Holodeck room and programs
The Villa SHALL have a Holodeck room on the lower deck with a control panel. The panel SHALL list every program the player has and run the chosen one in a simulated space that has its own camera, while the saucer holds station. Use at the exit arch (or, flying, anywhere) SHALL end the program and return the player to the holodeck room.

#### Scenario: Run two programs
- **WHEN** a player runs Sunset Beach, uses the deck chair, walks back to the arch and then runs the Seat Flight Course and flies every ring
- **THEN** the player gets Calm, the course is cleared with a best time saved and a training bonus, and Use returns them to the holodeck room

### Requirement: Programs are moddable data
Holodeck programs SHALL be Lua files under `holo/` discovered across base and every loaded mod, ordered by `order` then id, so that a mod adds a program without engine changes.

#### Scenario: A mod adds a program
- **WHEN** the game loads with the `holo_garden` fixture mod
- **THEN** its Zen Garden program is in the library, offered on the holodeck panel and runs

### Requirement: Program sources
Programs SHALL be starters, unlocked by decoding a data core found in a derelict at the lab bench, or bought from a trader.

#### Scenario: Decode a data core
- **WHEN** a player loots the tutorial vault's data core, banks it and decodes it at the lab
- **THEN** Resonant Memory is in the holodeck library

### Requirement: Replay and recreation feed the game
Derelict Replay SHALL show an explored site as a hologram with the route recorded while inside it and the pick-up marks. Resonant Memory SHALL mark a lead on the site of the mystery's next Echo and shelve its transcript.

#### Scenario: Memory gives a lead
- **WHEN** a player touches the memory in Resonant Memory
- **THEN** the next Echo's site is marked as a lead and the transcript is on the bookshelf

### Requirement: Upgrade modules
Modules SHALL raise the holodeck's space, detail and guest slots one level each when installed at the panel, and SHALL NOT go past the top level.

#### Scenario: Install an emitter array
- **WHEN** a player buys an emitter array at the trader and installs it at the holodeck panel
- **THEN** the holodeck's space goes from 6 to 10
