## ADDED Requirements

### Requirement: Sentry state machine
Every sentry SHALL follow Dormant → Alert → Locked → Disabled → Dormant with distinct light and sound telegraphs for each state, and SHALL stay leashed inside its ruin's bounding volume.

#### Scenario: Telegraph before acting
- **WHEN** a Watcher first detects the player
- **THEN** it spends at least 0.75 s in Alert (yellow light, rising tone) before becoming Locked

### Requirement: Watcher
A Watcher SHALL detect targets only within its sensor cone and its civ's size band, and when Locked it SHALL fire stun bolts that reduce shields, then hull, or Suit Charge on foot.

#### Scenario: Shrink below the band
- **WHEN** the saucer shrinks to Seat inside the cone of a Watcher whose band is M–XL
- **THEN** the Watcher returns to Dormant within 2 s

### Requirement: Snatcher
A Snatcher SHALL target only hot items. It SHALL latch onto a Pod or Seat hull (siphoning one hot item after 3 s) or onto the player on foot (taking one held item), then carry the item to its nest, where the player can recover it. It SHALL NOT be able to latch onto Villa or Cruiser.

#### Scenario: Recover from the nest
- **WHEN** a Snatcher steals a hot item and reaches its nest
- **THEN** the item sits in the nest as a pickup, and picking it up restores it as a hot item

### Requirement: Non-lethal tools
The MVP SHALL provide a Scanner pulse (reveals sentry cones, paths, and nests for 10 s) and a Jammer (sends sentries in a 15 m cone to Disabled for 12 s), both with Charge costs and cooldowns defined in Lua data. Neither the tools nor the sentries SHALL destroy anything.

#### Scenario: Jam a latching Snatcher
- **WHEN** the player Jams a Snatcher 2 s into a latch
- **THEN** the latch is cancelled, no item is taken, and the Snatcher reboots for 12 s

### Requirement: Grid consoles
Ruins containing sentries SHALL include at least one grid console as an on-foot hand-lock that disables every sentry in its zone until the player leaves the site.

#### Scenario: Grid off
- **WHEN** the player uses a grid console on foot
- **THEN** every sentry in that zone enters Disabled and stays Disabled until the player leaves the site

### Requirement: The dome is out of reach
Sentries SHALL NOT target, affect, or path into the dome interior.

#### Scenario: Inside the dome near a Watcher
- **WHEN** the player walks the Villa dome while a Locked Watcher fires at the hull
- **THEN** the hull takes damage, and nothing affects the player or the dome's contents
