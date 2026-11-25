## ADDED Requirements

### Requirement: Language per civ
Each civ SHALL own a design language with massing, primitive weights, symmetry, fractal, organic, proportion, aperture, edge, surface, materials, palette, style card, light, glyphs and sound, generated deterministically from its traits and the universe seed.

#### Scenario: Language present
- **WHEN** `tests/lua/language_spec.lua` runs "every civ has a language"
- **THEN** it passes

### Requirement: Signature pairing
Each civ's material table SHALL carry exactly one signature pairing from the odd-pair table, with the host as its dominant material, the guest as its accent and a crystal as its rare material.

#### Scenario: Every rule appears
- **WHEN** `tests/lua/language_spec.lua` runs "draws every signature rule and pulls materials by tech focus"
- **THEN** it passes

### Requirement: Skins never change envelopes
The parts a civ's signature rule adds to a relic SHALL stay outside every flyable box.

#### Scenario: Skin outside envelope
- **WHEN** `tests/lua/language_spec.lua` runs "skins never change envelopes: every rule's parts stay out of every flyable box"
- **THEN** it passes

### Requirement: Sense-driven lighting
A civ's light model SHALL follow its senses and reuse the existing lamp and light systems within 16 lights per view; an echo civ's lamps SHALL be fewer and dimmer and ripple.

#### Scenario: Echo civ is dark
- **WHEN** `tests/lua/language_spec.lua` runs "echo civs use ripple lighting"
- **THEN** it passes

### Requirement: Relics wear their builder's style
A relic SHALL draw with its civ's material colours, rib rhythm and signature rule, and the slice's Vyrr SHALL be dressed by the same generator with its authored fields as pins.

#### Scenario: Restyled relic
- **WHEN** `tests/lua/language_spec.lua` runs "restyles a relic: another civ's colours, ribs and signature"
- **THEN** it passes

#### Scenario: The Vyrr
- **WHEN** `tests/lua/language_spec.lua` runs "re-expresses the Vyrr through the grammar (its authored fields are pins)"
- **THEN** it passes
