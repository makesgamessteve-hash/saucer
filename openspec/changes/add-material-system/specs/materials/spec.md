## ADDED Requirements

### Requirement: Material library
The game SHALL load a moddable material library where each record has a kind (metal, crystal, organic, stone, enamel), a palette ramp from dark to bright and its kind's parameters, and SHALL turn a civ's dominant, accent, rare, signature ring and decay materials into the shader's per-view slots.

#### Scenario: Library loads
- **WHEN** `tests/lua/materials_spec.lua` runs "gives every record a kind and a dark-to-bright ramp"
- **THEN** it passes

#### Scenario: Slot mapping
- **WHEN** `tests/lua/materials_spec.lua` runs "fill the slots: the lung breathes, the decay has no vein pulse, the floors are still"
- **THEN** it passes

### Requirement: Signature pairing PIERCE
A civ whose signature rule is PIERCE SHALL show its guest material grown through its host material, every piercing ringed by the signature's wound material.

#### Scenario: Chrome through flesh
- **WHEN** `tests/lua/relic_spec.lua` runs "ring every PIERCE spine with a wound, breathe the lung hall and rot the plague hall"
- **THEN** every chrome spine has its wound ring

### Requirement: Fate changes materials
A plague civ's relic SHALL show a hall skinned in its decay material, whose slot has no vein pulse and the necrotic ramp.

#### Scenario: Plague stops pulse
- **WHEN** `tests/lua/materials_spec.lua` runs "fill the slots: the lung breathes, the decay has no vein pulse, the floors are still"
- **THEN** the decay slot's pulse is 0

### Requirement: Render-only animation
Organic wobble, breathing, vein pulses and crystal glow SHALL use render time only and SHALL NOT change any state hash.

#### Scenario: Hash unaffected
- **WHEN** `tests/game/relic.lua` runs the same inputs with materials full, lite and off, and every replay plays with `--materials off`
- **THEN** the end states match and every replay hash matches
