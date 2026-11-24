## ADDED Requirements

### Requirement: Relic slice civilization
The game SHALL ship one hard-seeded civilization for the first relic slice, the Vyrr, with every field a generated civilization has plus a design language (massing, edges, rhythm, senses, lamp colours) and a material table (dominant, accent and rare material, one signature rule and decay materials). Lookups by id and by a site's relic civ SHALL return it, and the generated roster SHALL NOT change.

#### Scenario: The Vyrr's materials
- **WHEN** `tests/lua/materials_spec.lua` runs "are membrane (dominant), chrome (accent) and amethyst (rare), signed PIERCE"
- **THEN** it passes

#### Scenario: Looked up from its relic
- **WHEN** `tests/lua/relic_spec.lua` runs "adds the Vyrr relic only with the debug entry, and only once"
- **THEN** `civs.of` on the relic site and `civs.by_id(nil, "vyrr")` both return the Vyrr
