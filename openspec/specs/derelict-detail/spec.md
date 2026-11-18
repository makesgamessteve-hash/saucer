# derelict-detail Specification

## Purpose
Derelicts get deterministic visual detail that stays out of the player's way and respects detail budgets and culling.

## Requirements

### Requirement: Deterministic visual detail for derelicts
Each derelict room, exterior solid and city link set SHALL get detail (panels, pipes, lit strips, glyphs, beams, cables, torn sections, debris and props) styled per kit. The detail SHALL be derived only from the ruin seed and the room or solid id, and SHALL NOT modify the ruin or the simulation state.

#### Scenario: Same seed, same detail
- **WHEN** the detail of every room, solid and link set is generated twice for seeds 42 and 7
- **THEN** both runs produce identical parts, and the ruin is unchanged

### Requirement: Detail stays out of the way
Detail SHALL keep clear of door corridors, hatch columns, loot slots and echo positions, and axis-aligned detail SHALL stay within its room bounds plus a small margin.

#### Scenario: Loot slots stay clear
- **WHEN** the detail of a room is generated
- **THEN** no loot slot of that room is inside the area reserved for detail

### Requirement: Detail budgets and culling
Every room, solid and link set SHALL respect a part budget. Detail meshes SHALL be built lazily, at most a fixed number per frame, and SHALL be drawn only for visible chunks within the detail distance.

#### Scenario: Budgets on several seeds
- **WHEN** detail is generated for seeds 42, 7 and 3
- **THEN** no room, solid or link set goes over its budget, and every kit gets detail

#### Scenario: Build cap per frame
- **WHEN** a frame is drawn next to a derelict whose detail is not built yet and the cap is 1
- **THEN** exactly one detail mesh is built that frame
