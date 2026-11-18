## ADDED Requirements

### Requirement: A galaxy of sectors
Each universe seed SHALL generate seven sectors: the home sector (generated exactly as before), a spine of three more ending in the Heart sector, and branches. Each sector SHALL have a name, a danger of 1 to 3 (the home sector 1), two or three civilizations (each sector shares one with the sector it branches from) and links to its neighbours. Far sectors SHALL hold three or four derelicts of their civilizations' kits and a trader.

#### Scenario: Same seed, same galaxy
- **WHEN** the galaxy is generated twice from seed 42
- **THEN** both have the same sectors, names, links, civilizations and sites

### Requirement: The sector map
Map (Tab, D-pad right, the touch Map button, XR right grip) SHALL open the sector map: where the party is, the jump being voted on, every sector with its danger, hops, civilizations and tags (HERE, RESONANT, HEART, visited), the party panel and the Xenoarchive. Sectors within the player's Fold Core range SHALL be selectable.

#### Scenario: Out of range
- **WHEN** a player with a tier 1 Fold Core opens the map in the home sector
- **THEN** only the sectors one hop away can be picked

### Requirement: Party fold jumps
Picking a sector SHALL propose a jump for the whole party. Every other player SHALL agree on their map (or anyone can call it off). Once everyone has agreed, the jump SHALL wait until every saucer is ready (Villa size, not reshaping, outside derelicts, out of the holodeck, Charge at least the Fold Core cost), then spool for 3 s and fold everyone to the new sector, where they arrive in formation facing its trader, each paying the Charge cost.

#### Scenario: Four players fold
- **WHEN** P1 proposes a jump to the next spine sector and P2, P3 and P4 agree
- **THEN** after the spool all four are in that sector, outside every site, with "Fold jump complete" messages

#### Scenario: Not ready
- **WHEN** everyone agreed but one saucer is in the Seat
- **THEN** the jump waits and that player is told why

### Requirement: Sectors remember what happened in them
Leaving a sector SHALL keep its traders, nests, caches, vault, hand-locks, grids, Lockdowns, decoys and gifts, and each player's looted slots and trails there; coming back SHALL restore them.

#### Scenario: Back home
- **WHEN** the party looted a site at home, jumps away and back
- **THEN** the looted slots stay empty

### Requirement: Fold Core tiers
A trader SHALL sell Fold Core tier 2 (2 hops, needs reputation Known) and tier 3 (3 hops, needs Trusted); a higher tier SHALL also cost less Charge per jump. A jump's range SHALL be the proposer's tier.

#### Scenario: Upgrade
- **WHEN** a player with enough credits and reputation buys tier 2
- **THEN** sectors two hops away become selectable on that player's map
