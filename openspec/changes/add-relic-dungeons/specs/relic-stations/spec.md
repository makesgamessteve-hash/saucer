## ADDED Requirements

### Requirement: Warren relic
A relic SHALL be a warren: 40 to 80 Villa-class spaces (halls of several sizes, trunk corridors and shafts) on 3 to 5 levels, 15 to 30 Seat chambers, and a heart hall of about 480 x 160 x 480 m, with no two spaces overlapping.

#### Scenario: Dungeon scale
- **WHEN** `tests/lua/relic_spec.lua` runs "is a dungeon: 40-80 Villa spaces on 3-5 levels, 15-30 Seat chambers, the heart past it all"
- **THEN** it passes

#### Scenario: Ways round
- **WHEN** `tests/lua/relic_spec.lua` runs "joins its halls with loops, dead ends and shafts, and no two spaces overlap"
- **THEN** it passes

### Requirement: The heart deep in the warren
The heart SHALL be entered only from the lowest level, at least 1 km of shortest Villa route from the maw, and the Villa SHALL be able to fly there from the maw without folding.

#### Scenario: Heart depth
- **WHEN** `tests/lua/relic_spec.lua` runs "puts the heart deep: entered from the lowest level only, at least 1 km of route from the maw"
- **THEN** it passes

#### Scenario: Flying to the heart
- **WHEN** `tests/game/relic.lua` flies the Villa from the maw along the warren's doors to the heart (seeds 42 and 7)
- **THEN** the Villa arrives in the heart at its own size

### Requirement: Heart engine
The heart SHALL hold an engine: a solid column floor to ceiling in its middle, drawn as a spindle with turning hoops whose motion is render-only.

#### Scenario: Engine column
- **WHEN** `tests/lua/relic_spec.lua` runs "stands the heart's engine as a solid column, floor to ceiling, in the middle of the heart"
- **THEN** it passes

### Requirement: Seat branches with their bays
Every Seat branch SHALL open through a class-1 port, hold only Seat-class rooms and at least one chamber, and have a fold bay with a cradle in its hall within 30 m of the port; no bay SHALL stand over a floor hole and no cushion or lobe SHALL cover a port or a shaft.

#### Scenario: Branches
- **WHEN** `tests/lua/relic_spec.lua` runs "gives every Seat branch a port, Seat-class rooms only, a chamber and a fold bay by the port"
- **THEN** it passes

#### Scenario: Ports clear
- **WHEN** `tests/lua/relic_spec.lua` runs "never cover a Seat port or a shaft with a cushion or a lobe"
- **THEN** it passes

### Requirement: Relic phenomena
A relic SHALL hold strange, harmless phenomena chosen from its civ's list and placed deterministically inside its halls, corridors and heart; they SHALL move only with the clock and the eye and never affect the state, collide or deal damage.

#### Scenario: Placement
- **WHEN** `tests/lua/relic_spec.lua` runs "fill the halls with strange sights from the civ's own list, four in the heart, none in the engine"
- **THEN** it passes

#### Scenario: Render-only motion
- **WHEN** `tests/lua/relic_spec.lua` runs "move only with the clock and the eye, stay in their room and never touch the state"
- **THEN** it passes

### Requirement: Deterministic quick generation
The same seed SHALL give the same warren and its phenomena, other seeds other warrens, and a try SHALL take well under a second.

#### Scenario: Seeds
- **WHEN** `tests/lua/relic_spec.lua` runs "is a function of the seed: the same seed the same warren, another seed another one, quickly"
- **THEN** it passes

### Requirement: Area culling
Room meshes SHALL be built only when the eye comes within a few doors of them and freed beyond, and only the rooms a few doors from the eye's room SHALL draw.

#### Scenario: Lazy meshes
- **WHEN** `tests/lua/relic_spec.lua` runs "build room meshes as the eye comes near, free them as it leaves, and keep what draws under the web cap"
- **THEN** it passes

### Requirement: Glows add light
A glow sprite (a lamp's, the idol's, the engine's) SHALL draw as a smooth camera-facing falloff in its tint that only adds light: it SHALL never darken what is behind it, and SHALL not show the sprite's palette texels as blocks.

#### Scenario: Glow golden
- **WHEN** `tools/shots/materials.sh` renders the heart and the idol with and without their glow sprites at one render time
- **THEN** `golden_compare.py --brighter` finds at most 0.2% of the pixels darker with the sprites and at least 0.2% brighter

#### Scenario: Soft textures
- **WHEN** the C test marks a texture soft and back, and tries a bad id
- **THEN** the flag follows and the bad id is refused

### Requirement: Grown far hull
Outside the relic, rooms beyond the full-detail distance SHALL draw as lumpy flesh blobs over their boxes (one to three along a long room), not as boxes.

#### Scenario: Far blobs
- **WHEN** `tests/lua/relic_spec.lua` draws the relic from far outside
- **THEN** far rooms draw as blobs that stay centred in their boxes, cover them and keep their axes
