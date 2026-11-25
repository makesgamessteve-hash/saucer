## ADDED Requirements

### Requirement: Material shading
The renderer SHALL shade per material slot: metals by a matcap reflection mapped through a palette ramp plus Blinn specular and fresnel; crystals by facets, emission and fake refraction from the same fetch; organics by wrap and subsurface tint, wobble, breathing and vein pulse. Slot 0 SHALL take the unchanged plain path.

#### Scenario: Material shots
- **WHEN** `tools/shots/materials.sh` renders the relic reference scene with materials full and off
- **THEN** both images match the goldens in `tests/golden/` within tolerance

### Requirement: Material budgets
Materials SHALL add at most one texture fetch per pixel and at most 10% frame cost, and SHALL default to lite on the web (no refraction or wobble, half breathing).

#### Scenario: Budget gate
- **WHEN** `tools/shots/relic_perf.sh` flies the relic with materials off and full
- **THEN** the full run's frame p95 is at most 1.1x the off run's and its work p95 is at most 16.6 ms

### Requirement: Materials setting
The game SHALL offer materials full, lite and off (`--materials`, the settings table), where off renders today's look.

#### Scenario: Off matches legacy
- **WHEN** `tools/shots/materials.sh` renders the seed 42 default view with materials off
- **THEN** it is pixel-identical to the same view rendered before the material system

### Requirement: Golden shots in CI
Every pull request SHALL render the material golden shots under Xvfb and Mesa and compare them with `tests/golden/`, and the relic scene with materials full SHALL differ from off by a mean of at least 9.5 per channel.

#### Scenario: CI golden job
- **WHEN** the `golden` job of `.github/workflows/ci.yml` runs `tools/shots/materials.sh`
- **THEN** every shot matches its golden within tolerance and full differs from off by at least 9.5

### Requirement: Fate materials
A civ's fate SHALL age its material slots (war of silence scorches every ramp and dulls metals, ascension makes the rare crystal blaze and tints the skin's rim, sleep stills glow, pulse, wobble and breathing, flight strips the accent metal and darkens the rare crystal, schism gives the breathing skin the decay ramp), while plague keeps its look and the material library is never changed.

#### Scenario: Fates
- **WHEN** `tests/lua/materials_spec.lua` runs "leaves the plague's look to its decay slot and ages the others by their fate"
- **THEN** it passes

### Requirement: Sparkle, brushing and ripples
A crystal slot SHALL be able to sparkle (facet cells that twinkle with render time), a metal slot to stretch its highlight across a brushing and to ripple its normal like a liquid, packed as a sixth vec4 per slot; lite SHALL drop the sparkle and halve the ripple, and off SHALL pack every slot plain.

#### Scenario: Packing
- **WHEN** the C test `material_pack_modes` runs
- **THEN** sparkle packs only for crystals in full, brushing and ripple only for metals, and lite halves the ripple

#### Scenario: Library
- **WHEN** `tests/lua/materials_spec.lua` runs "carries a crystal's sparkle and a metal's brushing and ripple into its slot"
- **THEN** it passes

### Requirement: Headset comfort
In a headset view the material slots SHALL drop the crystal sparkle, halve the organic wobble and never breathe faster than one cycle in 4 seconds.

#### Scenario: XR slots
- **WHEN** `tests/lua/materials_spec.lua` runs "drops the sparkle, halves the wobble and slows the breathing to at least 4 s in a headset"
- **THEN** it passes
