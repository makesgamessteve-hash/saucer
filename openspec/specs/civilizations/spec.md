# civilizations Specification

## Purpose
Each universe generates its own civilizations, whose names, glyphs and styles flavour sites, items and music.

## Requirements

### Requirement: Generated civilizations
Besides the two authored civilizations, each seed SHALL generate six more from `civs/traits.lua`: a pronounceable unique name, a body (human, tiny or giant, which sets its Watchers' sentry band), a shape with the derelict kits it builds, the item domains it made, a fate, a temperament, a tint, a glyph and music (scale, root, tempo, voice). The same seed SHALL always give the same civilizations; mods MAY override the traits file.

#### Scenario: Deterministic
- **WHEN** the civilizations of seed 42 are generated twice
- **THEN** names, kits, domains and music are identical, and no two civilizations share a name
