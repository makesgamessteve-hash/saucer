## ADDED Requirements

### Requirement: Spinning layer collision
A trader station's spinning layer SHALL collide with saucers where it stands at the current sim tick: its spores and nodes as spheres, its limbs, splinters and plates as capsules, its seed rings as annuli about the spin axis and the Gyre's shells as tori. The layer's angle SHALL come from the sim tick, the same as the view's, so every peer and every replay sees the same collisions.

#### Scenario: Shapes in the layout pass
- **WHEN** a station of each family is generated with and without triangles
- **THEN** both give the same spin shapes and the same hash

#### Scenario: Flying into the layer
- **WHEN** a saucer moves into a spin shape at a tick where the layer has turned
- **THEN** it is pushed out and the move counts as blocked
