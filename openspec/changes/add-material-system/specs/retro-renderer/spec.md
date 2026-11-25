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

