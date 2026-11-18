## ADDED Requirements

### Requirement: Wake-up start
A new game SHALL start with every player in "wake" mode beside their bed on the lower deck, with a title panel offering "Get up" and "Load saved game". The panel SHALL be driven by the move stick (up and down) and Use on every input device, and no other action SHALL work while it is open.

#### Scenario: Getting up
- **WHEN** a new game starts and the player presses Use
- **THEN** the player stands in the bedroom on foot and is told where the helm is

### Requirement: Sliding doors
The bedroom and bathroom SHALL have doors that slide open while a player's body is on their deck within reach, and close otherwise. A door SHALL be solid while less than 75 % open.

#### Scenario: Walking through the bedroom door
- **WHEN** the player walks from the bed to the engine room
- **THEN** the bedroom door opens on approach, lets them through, and closes behind them

### Requirement: Furniture Use
Use on foot within reach of a station SHALL run that station's action: the kitchen makes the player well fed (Charge regenerates 1.5× as fast for five sim minutes), the shower refreshes, the engine console reads out Charge, the lab bench and trade terminal respond as places, and the bed opens a panel to sleep or load. Sleeping SHALL refill Charge and save the game, and SHALL be refused inside a derelict site.

#### Scenario: Cooking a meal
- **WHEN** the player uses the kitchen
- **THEN** they are well fed and Charge regenerates faster until the meal wears off

#### Scenario: Sleeping saves
- **WHEN** the player picks "Sleep until morning" at the bed outside a site
- **THEN** Charge is full and the game is saved

### Requirement: Helm console that keeps the view
The helm SHALL be a low desk with a radar of nearby sites, the trader and future markers, plus two side screens with live Charge, hull, shield, hold slots (hot and banked) and the size ladder. No part of it SHALL rise above the pilot's sight line through the dome.

#### Scenario: Flying from the helm
- **WHEN** the player flies from the helm
- **THEN** the view ahead through the dome is unobstructed and the console shows live readouts

### Requirement: The fold packs the rooms away
While folding from the Villa, the room groups SHALL pack away one after another, farthest from the pilot first. Each SHALL flatten, then slide into fold-space at the pilot's feet. The hull SHALL keep its full size until the rooms are packed, then shrink about the pilot's eye. Unfolding SHALL grow the hull first and then unpack the decks and rooms nearest first.

#### Scenario: Staggered packing
- **WHEN** the player folds to the Seat while standing in the kitchen
- **THEN** some rooms are already packed while others are still out, the farthest room finishes first, and the eye does not move
