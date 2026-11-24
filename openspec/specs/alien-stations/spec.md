# alien-stations Specification

## Purpose
Trader stations built in one of four alien hull families (Reef, Lattice, Helix, Gyre) chosen per seed, with alien props, palettes, lamps and an on-foot alien wing off the market, while docking and trading keep working.

## Requirements

### Requirement: Alien architecture families
Each trader station SHALL be built by one alien architecture family chosen from its seed: coral (Reef), crystal (Lattice), spiral (Helix) or shells (Gyre). The family SHALL shape the stem, the body, the docking pods and the spinning layer. Every station SHALL also carry floating glyph monoliths, cocoon clusters, lit conduits, alien glyph signs and an alien palette.

#### Scenario: Families by seed
- **WHEN** stations are generated for many seeds
- **THEN** all four families appear and each station's family and palette follow from its seed alone

#### Scenario: Same family inside and out
- **WHEN** the player walks into a station's alien wing
- **THEN** its chambers are named and coloured by the same family as the hull outside

### Requirement: Alien stations are bigger
A trader port SHALL be at least 1.8 km long and 1.6 km across, about twice the megastructure it replaces, and an outpost SHALL be a quarter of a port's size. The hangar cell SHALL stay under a thousandth of a port's bounding volume, and the generated body SHALL stay inside the bounding box that placement uses.

#### Scenario: A port's extent
- **WHEN** a port is generated
- **THEN** its extent is at least 1800 m by 1600 m by 1600 m and every solid lies inside it

### Requirement: Placement by the hull's box
A station's dock anchor SHALL be placed where the hull's bounding box keeps at least 120 m of room from every site, the vault and the arrival point. Among the places that fit, the anchor SHALL be as near the start as possible, and the way from the arrival point to the hangar mouth SHALL not cross the hull.

#### Scenario: Many seeds
- **WHEN** home sectors are generated for many seeds
- **THEN** every station's box clears every site and the vault by the margin

### Requirement: Alien wing inside
The walkable station SHALL grow an alien wing off the market. The wing SHALL be chambers (atriums, vertical shafts, brood halls, gardens and shrines) joined by straight or doglegged passages. Every chamber and passage SHALL be reachable on foot from the arrival hangar, and every walk link SHALL be clear of solids. The concourse, market, bar and hangars SHALL keep their layout.

#### Scenario: Reachable chambers
- **WHEN** the layout is generated for many seeds
- **THEN** the nav graph reaches every area from the arrival hangar and every link is walkable

#### Scenario: Shafts
- **WHEN** a wing has a vertical shaft
- **THEN** it is at least 36 m tall and its walls are lit at several heights

### Requirement: Alien stations stay playable
Docking with the tractor beam, the far hangar's pod, trading, the pocket saucer, station visits, co-op and saves SHALL work as before on alien stations. Hull generation SHALL be deterministic and SHALL use no wall clock.

#### Scenario: Dock at an alien station
- **WHEN** the saucer flies to an alien station's bay and is captured by the beam
- **THEN** it is guided onto the pad and docks, and the player can walk into the station and through the wing
