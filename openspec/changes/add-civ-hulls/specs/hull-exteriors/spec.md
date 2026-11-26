## ADDED Requirements

### Requirement: A civ's hull dress
Every civilisation SHALL dress the outside of what it builds with a silhouette motif, a surface pattern from its signature rule, a palette from its own material table and signal lights that blink by its light model, all a pure function of the civ and its roster; a roster SHALL hand out the motifs so that no two of its first eight civs share one.

#### Scenario: gives every civ of a roster its own motif, and the whole dress differs between any two
- **WHEN** `tests/lua/civhulls_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: turns a part's +y onto any direction
- **WHEN** `tests/lua/civhulls_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: grows every motif and lays every pattern, with lit parts and boxes inside what is drawn
- **WHEN** `tests/lua/civhulls_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Stations in their builder's dress
A trader station SHALL wear the dress of the civ that built it (a port its sector's first site's civ, a city's outpost the city's): a crown of the motif behind its body and a crest along its stem, solid as drawn, inside the station's box and behind the hangar cell, the civ's pattern, palette and material slots, self-lit far silhouette and signal lights readable from kilometres away, without changing the station's shape, box, placement or random stream.

#### Scenario: keeps the family's shape, box and stream, and adds the crown, crest, pattern and signals
- **WHEN** `tests/lua/civhulls_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: is built by its sector's first site's civ; a city's outpost by the city's
- **WHEN** `tests/lua/civhulls_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: signals blink by the light model and read from kilometres away
- **WHEN** `tests/lua/civhulls_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: shades as its builder's materials, or its plain twin when another civ's relic holds the view
- **WHEN** `tests/lua/civhulls_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Relics in their builder's dress from afar
A relic seen from beyond its near range SHALL draw each big room's far hull in its builder's edge language, palette, pattern and motif with lit bands and signal lights, self-lit so it does not read as a dark silhouette, out to the kit's relic range and not beyond.

#### Scenario: wears the civ's edges, pattern, motif and lit bands, and differs from civ to civ
- **WHEN** `tests/lua/civhulls_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: draws its far hulls and signals out to the kit's relic range, and nothing beyond
- **WHEN** `tests/lua/civhulls_spec.lua` runs its scenario of this name
- **THEN** it passes
