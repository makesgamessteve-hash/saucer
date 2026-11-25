## ADDED Requirements

### Requirement: Relic slice civilization
The game SHALL ship one hard-seeded civilization for the first relic slice, the Vyrr, with every field a generated civilization has plus a design language (massing, edges, rhythm, senses, lamp colours) and a material table (dominant, accent and rare material, one signature rule and decay materials). Lookups by id and by a site's relic civ SHALL return it, and the generated roster SHALL NOT change.

#### Scenario: The Vyrr's materials
- **WHEN** `tests/lua/materials_spec.lua` runs "are membrane (dominant), chrome (accent) and amethyst (rare), signed PIERCE"
- **THEN** it passes

#### Scenario: Looked up from its relic
- **WHEN** `tests/lua/relic_spec.lua` runs "adds the Vyrr relic only with the debug entry, and only once"
- **THEN** `civs.of` on the relic site and `civs.by_id(nil, "vyrr")` both return the Vyrr

### Requirement: Roster size
The universe SHALL generate a roster of `universe.roster_size` civilizations (default 8, clamped 6-10) from the universe seed, keeping the authored civs in slots 1-2.

#### Scenario: Default roster
- **WHEN** `tests/lua/civroster_spec.lua` runs "default roster: 8 civs and slots 1-2 are Velari and Oquun"
- **THEN** it passes

### Requirement: Trait axes
Each civ SHALL have body scale, biology, senses, social structure, tech focus, values, fate and era, and its legacy body, domain, fate and temperament fields SHALL be derivable from them.

#### Scenario: Legacy fields
- **WHEN** `tests/lua/civroster_spec.lua` runs "legacy fields derive"
- **THEN** it passes

### Requirement: Roster diversity
A roster SHALL cover at least 3 massing archetypes and 2 body scales, and no two civs SHALL share more than 3 axis values.

#### Scenario: Diverse over seeds
- **WHEN** `tests/lua/civroster_spec.lua` runs "every roster over 200 seeds meets the diversity rule"
- **THEN** it passes

### Requirement: Generated history
The universe SHALL generate a deterministic history with 5-7 beats per civ and a relation (trade, war, alliance, tutelage, conquest, ignorance) for each pair with overlapping eras.

#### Scenario: Same seed same history
- **WHEN** `tests/lua/civroster_spec.lua` runs "same seed same history"
- **THEN** it passes

### Requirement: Palimpsest relics
A civ conquered by another SHALL have 10-25% of its relics carry a wing in the conqueror's design language.

#### Scenario: Conquest wing
- **WHEN** `tests/lua/civroster_spec.lua` runs "conquest adds wings"
- **THEN** it passes

### Requirement: Civ names and lore
Each civ SHALL have an endonym drawn from its senses, a trader exonym, unique station names and scanner lore lines from its history.

#### Scenario: Names
- **WHEN** `tests/lua/civroster_spec.lua` runs "names a civ from its senses and gives it a trader nickname"
- **THEN** it passes
