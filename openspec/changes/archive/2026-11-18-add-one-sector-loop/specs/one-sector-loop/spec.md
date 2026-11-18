## ADDED Requirements

### Requirement: Lab bench queue
The lab bench SHALL queue jobs per player: identifying an unidentified item SHALL cost the Charge set in `economy/economy.lua` and take `identify_seconds × tier` of sim time, and decoding an Echo SHALL take `decode_seconds`. Jobs SHALL run only while the saucer is the Villa and not reconfiguring, including in flight. Unidentified items SHALL be labelled by civ, category and tier only.

#### Scenario: Identify while flying to the trader
- **WHEN** a player queues a tier 2 item and flies the Villa to the trader
- **THEN** the item is identified 60 s of sim time later and shows its real name

#### Scenario: The bench folds away
- **WHEN** the saucer folds to the Seat with a job running
- **THEN** the job pauses and resumes once the Villa is back

### Requirement: Trade terminal
Docked within `dock_range` of a trader, the trade terminal SHALL list every hold item with its offer (Echoes and unique Curios as "Not for sale"), Charge refills and hull repair priced from Lua data, and every transaction SHALL save the game at once. Away from a trader it SHALL say that no trader is in range.

#### Scenario: Selling saves
- **WHEN** a player sells an item at the terminal
- **THEN** the credits rise by the offer, demand for that category and civ drops by 0.05 and the save file is written

### Requirement: Sentry placement and leash
Sentries SHALL be derived from the ruin layout, not saved: a Watcher in every great hall that is not the entrance, looking back at its door, and a Snatcher in every duct branch with its nest in the deepest small room. The tutorial derelict (site 1) SHALL have none. A Snatcher SHALL only notice a Seat inside its duct branch.

#### Scenario: Leaving the duct
- **WHEN** a Seat with hot cargo flies out of a Snatcher's branch while it is Disabled
- **THEN** the Snatcher does not follow it into the hall

### Requirement: Jammer pulse
Besides its cone, the Jammer SHALL disable every sentry within `near` metres all round and any Snatcher latched onto the jamming player's hull, and jamming an already Disabled sentry SHALL restart its reboot timer.

#### Scenario: Jam a Snatcher in its nest
- **WHEN** a player jams next to a Snatcher sitting in its nest
- **THEN** it is Disabled for 12 s whatever way the player faces

### Requirement: Resonant vault
Decoding the Where Echo SHALL reveal the Resonant vault at a seeded point in open space. Arriving within 80 m with the Key Echo SHALL use up the Key, open the vault and solve the chain, and the vault SHALL then hold one unique Curio, never sold or lost, whose pickup shows the teaser "The signal continues beyond the fold."

#### Scenario: Open the vault
- **WHEN** a player carries the Key to the revealed vault and tractors the Curio
- **THEN** the mystery is solved, the Curio is in the hold and the teaser appears

### Requirement: Milestone 3 save diffs
A save SHALL also record each trader's demand, the sim clock, Snatcher nests, Fold Retreat caches, the vault, and per player the credits, the lab queue and the next item uid. Sentry state SHALL restart Dormant after a load.

#### Scenario: Load restores the economy and the chain
- **WHEN** a player sells, sleeps, changes things and loads
- **THEN** credits, demand, the lab queue, mystery progress, the vault and the hold are exactly as they were at the save
