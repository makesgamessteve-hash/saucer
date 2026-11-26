## ADDED Requirements

### Requirement: Distinct forms instead of a shared bubble

Every former circular bubble or orb billboard SHALL be drawn as a form that fits what it is (a flare for a light, a shard for a mote, a ring for an echo, a spark for loot, a streak for a pulse or a beam mote, a chevron for a warning, a slit for a signal or an eye, a flat pool for a sentry's floor light, a tall figure for a hall shadow, a ring mesh for a ripple). The soft circular disk SHALL not be the default look of those uses. The forms SHALL stay cheap on WebGL2.

#### Scenario: knows each form and draws it with that name
- **WHEN** `tests/lua/sprites_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: lights, motes, echoes, loot, signals and warnings each use a different form
- **WHEN** `tests/lua/sprites_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a ripple is a ring on the floor and a shadow is a tall figure, not a bubble
- **WHEN** `tests/lua/sprites_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a city swarm is shards and a lane pulse is a streak along the lane
- **WHEN** `tests/lua/sprites_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: does not change simulation state
- **WHEN** `tests/lua/sprites_spec.lua` runs its scenario of this name
- **THEN** it passes
