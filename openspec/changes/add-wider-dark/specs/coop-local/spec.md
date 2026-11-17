## ADDED Requirements

### Requirement: Join a running game
With co-op on, the engine SHALL send a command frame for every one of the four player slots (zero for empty slots), and a slot SHALL join on its first button press with a new saucer beside player 1's and its own body, hold, Charge and loot. A on an unclaimed gamepad, or F2 for the right half of the keyboard, SHALL claim the next free slot; joins SHALL be refused during an XR session.

#### Scenario: Three more players join
- **WHEN** a one-player game runs with co-op on and slots 2, 3 and 4 each press Use
- **THEN** there are four players, each in a separate saucer more than 20 m from the others

#### Scenario: No joins in XR
- **WHEN** an XR session is running and F2 is pressed with co-op on
- **THEN** no slot claims the split keyboard

### Requirement: Split screen layouts
Split screen SHALL follow the number of players in the game: one full view; two players side by side (stacked with `--split horizontal`); three or four players in quarters, a third player's spare quarter showing the sector map, the party and how to join. Each view SHALL draw its own player's camera and HUD, and only player 1's view SHALL drive the looping sounds and the music. XR SHALL stay single-player and is never split.

#### Scenario: Two players
- **WHEN** a second player joins
- **THEN** the screen splits into a left and a right half of equal size

#### Scenario: Three players
- **WHEN** a third player joins
- **THEN** the screen splits into quarters and the fourth quarter shows the sector map

### Requirement: A split keyboard
Bindings with the `key2:` device SHALL belong to the right half of the keyboard (I J K L move, the arrows look, O and U climb and dive, Enter use, comma and period fold, right Shift beams, semicolon scans, backslash opens the map). While the keyboard is split, the left-hand player SHALL ignore every key the right half uses and keep the rest of the keyboard and the mouse. `--split-keyboard` SHALL split it from the start for player 2.

#### Scenario: Enter belongs to the right half
- **WHEN** the keyboard is split and Enter is pressed
- **THEN** the right-hand player's Use is pressed and the left-hand player's is not, while G still works for the left-hand player

### Requirement: Gifts between saucers
From the party panel a player SHALL be able to eject an item from the hold (never an Echo) for one player or anyone; it SHALL float below the saucer as a gift that only that player (or anyone) can beam up. Docked players SHALL also be able to hand items over at the gift table in either dome.

#### Scenario: Gift through space
- **WHEN** P2 ejects a curio for P1 and P1 beams it up
- **THEN** the curio leaves P2's hold and arrives in P1's

### Requirement: Docking and dome visits
Two saucers within 90 m SHALL be able to dock (one asks, the other accepts on the party panel). A docked player SHALL be able to visit the other's dome on foot, seeing it from inside, using its gift table, and go home from the map. Drifting apart or a fold jump SHALL undock everyone.

#### Scenario: Visit
- **WHEN** P1 and P2 are docked and P2 visits
- **THEN** P2's view is inside P1's dome, P1 sees P2's body walking there, and Use at the table opens the gift table

### Requirement: Co-op is deterministic, saved and replayed
Joins SHALL happen only through command frames, so a replay recorded with co-op on (a `slots 4` line) SHALL replay the joins at the same ticks. A save SHALL keep every player in the game, and loading it SHALL bring the extra players back.

#### Scenario: Save with four players
- **WHEN** a four-player game is saved in a far sector and loaded
- **THEN** four players are back in that sector with their holds
