## ADDED Requirements

### Requirement: Megastructure stations
Each trader station SHALL be a generated 3D megastructure at least half a kilometre across, whose parts include a visitor arm, a hub, at least one spinning ring on spokes, an aft spine, docking-arm pods, masts and several hundred small details. The hangar cell for the player's saucer SHALL be a small part of it (under one percent of its volume).

#### Scenario: Seen from afar
- **WHEN** the player looks at the station from a few hundred metres
- **THEN** the whole structure fills the view and the saucer's bay is a small mark on the arm

#### Scenario: Outposts
- **WHEN** a sector has an outpost
- **THEN** it is drawn with the same generator at about a tenth of the size

### Requirement: Seeded and deterministic
A station's layout SHALL depend only on the sector seed, the sector and the trader index. The same inputs SHALL give the same layout (same hash), different seeds SHALL differ, and nothing in the layout SHALL use the wall clock.

#### Scenario: Same seed twice
- **WHEN** a layout is generated twice from one seed
- **THEN** both have the same hash, solids, lights and triangle counts

#### Scenario: Another seed
- **WHEN** layouts are generated from several seeds
- **THEN** they differ in size or palette

### Requirement: Levels of detail and budgets
The station view SHALL draw static meshes per layer and choose the level by the distance to the hull's bounding box: a silhouette far away, the hull and rings nearer, the greebles and windows close. A layout SHALL stay inside the triangle budgets of the kit (core, detail, far), and the blinking beacons SHALL be limited in number and range.

#### Scenario: Far away
- **WHEN** the camera is beyond the far distance
- **THEN** only the silhouette layer is drawn

#### Scenario: Close
- **WHEN** the camera is within the detail distance
- **THEN** the core, ring, detail and ring-detail layers are drawn

### Requirement: Physical hull
The station's arm, hub, rings, pods and wings SHALL be solid for the saucer, while the dock anchor, the hangar cell's mouth and the approach corridor stay free.

#### Scenario: Flying into the arm
- **WHEN** the saucer flies into the visitor arm
- **THEN** it is stopped by the hull

#### Scenario: Flying to the bay
- **WHEN** the saucer flies to the dock anchor from the open side
- **THEN** nothing blocks it

### Requirement: Dock flow and approach lights
The tractor beam SHALL capture a saucer within its capture radius of the bay mouth and guide it into the bay, and a corridor of guide lights SHALL lead from the mouth outward. The far hangar SHALL be a docking pod on the structure and a saucer unfolded there SHALL count as docked.

#### Scenario: Beam from the corridor
- **WHEN** the saucer is within the capture radius of the mouth and the player lets go
- **THEN** the beam takes it into the bay

#### Scenario: Far hangar
- **WHEN** the player leaves through the far hangar
- **THEN** the saucer appears at the pod's mouth, docked at the same trader

### Requirement: Placement
The station SHALL be placed so that its whole hull clears the arrival, the vault and every site.

#### Scenario: Several seeds
- **WHEN** sectors are generated from many seeds
- **THEN** the hull's bounding sphere overlaps no site
