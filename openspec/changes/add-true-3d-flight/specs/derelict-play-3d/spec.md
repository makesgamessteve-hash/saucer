## ADDED Requirements

### Requirement: Flying inside multi-level derelicts
Collision SHALL apply on every axis, so floors, ceilings and undersides stop the saucer just as walls do. A saucer SHALL be able to pass through a hatch it fits, and ducts SHALL force the Seat. Physics queries SHALL use a broadphase whose results equal a brute-force search, with ties broken by the lowest id.

#### Scenario: Traversing levels
- **WHEN** the Villa flies from outside the tutorial derelict through a hatch to the room furthest from the entrance level, pushes against that room's ceiling and floor, and flies back out
- **THEN** it reaches the room, stays between its floor and ceiling, and leaves the site

#### Scenario: The underside holds
- **WHEN** the saucer lifts into a derelict's lowest room from below
- **THEN** it stops against the hull and does not pass through

### Requirement: Sentries and tools in 3D
Watchers SHALL look along the axis of the door they guard. Shaft Watchers SHALL sit at the top looking down. Watcher cones and line of sight SHALL use pitch as well as yaw. Snatchers SHALL patrol along their room's longest axis, including vertical chutes. The scanner, the jammer, mystery steps and cache drops SHALL use full 3D distances.

#### Scenario: A Watcher above
- **WHEN** a Villa-sized saucer rises up a shaft toward the Watcher at its top
- **THEN** the Watcher's cone, pitched down the shaft, sees it
