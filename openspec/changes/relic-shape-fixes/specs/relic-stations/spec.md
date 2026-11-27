## ADDED Requirements

### Requirement: Every relic layout turns up in real worlds
The social structures SHALL between them hand out all eight relic layouts (organism, lattice, shell, ring, helix,
hive, cluster, spine), so every layout is built in some world's relics.

#### Scenario: All eight in many worlds
- **WHEN** `tests/lua/relicunique_spec.lua` runs "every layout turns up in real worlds: the builders' social structures hand out all eight"
- **THEN** it passes

### Requirement: A shaped wall is dressed like the box's own
A shaped hall's wall SHALL carry chrome ribs, floor to ceiling, spaced along each whole run of its contour, and
chrome bands at the rows the box's cushions split into, all on the free side of the wall; the wall's slabs SHALL NOT
run past their segments.

#### Scenario: Ribs and bands along the runs
- **WHEN** `tests/lua/relicshape_spec.lua` runs "joins the contour into runs and dresses every shaped wall with ribs and bands on the free side"
- **THEN** it passes

### Requirement: A decay crystal does not read as static
A civ's decay material, when it is a crystal, SHALL be skinned over its hall with the same calmed look as a dominant
crystal (a third of its sparkle, toned ramp, rim and reflection), and without a vein pulse.

#### Scenario: Calmed decay crystal
- **WHEN** `tests/lua/relicplay_spec.lua` runs "a crystal decay material skins its hall calmed too: grey static no more; an organic one is untouched"
- **THEN** it passes
