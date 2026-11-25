## Why

The relic design (`design/civs-and-relics.md` §2) gives every civilization a design language: its massing,
shapes, materials, light, glyphs and sound, generated from its traits. The first relic slice hand-built one look
(the Vyrr). With the roster (`add-civ-roster`) every universe now has eight civs with trait axes; this change gives
each of them a language and lets a relic wear any civ's style, so stations look different depending on who built
them.

## What Changes

- **Language per civ** (`sim/language.lua`, `civs/languages.lua`): massing weights (the civ's archetype first),
  primitive weights by biology, symmetry (bilateral, radial n = 3/5/7, fractal, none), fractal depth, organic warp,
  proportions, aperture, edge, surface, a material table, palette row, style card path, light model, glyphs and
  sound. Deterministic from the universe seed and the civ's axes; the authored civs use seed 0 so they look the same
  in every universe. Render-only: no state, roster hash or replay change.
- **Materials with one signature pairing** drawn from the odd-pair table (§2.3.3), weighted by how well the pair fits
  the civ's tech focus, values and biology: the host is the dominant material, the guest the accent, a crystal the
  rare one; the signature's ring material and the fate's decay materials complete it.
- **Light by senses** (§2.5): chromatic (sight), ripple (echo: dim lamps swept like sonar), fogbank (chemical),
  arc (field: flicker), orbit (tidal: lamps circling their posts), dark (touch). The light model thins and dims the
  relic's lamps (the heart keeps its glow), always within the 16-light budget; the motion is a function of the clock.
- **Relics restyled by their civ** (`view/relic.lua`): part colours from the civ's materials, rib spacing from its
  rhythm, and the signature rule decides what grows where the Vyrr's spines grow: PIERCE spines, CRUST crystal
  blooms, PLATE hexagonal plates, ENCASE crystal domes over a guest knot, INLAY and FLOW discs with a vein ring.
  Every rule's parts stay outside every flyable box. `relic.set_style(civ)` restyles every relic (shot scripts).
- **The Vyrr through the grammar**: the slice civ gets trait axes and is dressed by the same generator; its authored
  fields (spine massing, ribs, lamp colours, material table) are pins, so the slice keeps its look.
- Not in this change (later tasks under this id): shape-grammar rules beyond the signature (RADIAL / MIRROR / GROW /
  WARP on halls), per-civ palette rows and generated style-card textures (offline art pipeline), glyph strips and
  per-civ sound beyond the language data.

## Impact

- Specs: `design-language` (ADDED)
- Code: `sim/language.lua`, `civs/languages.lua`, `sim/civs.lua`, `sim/relic.lua`, `civs/relic_slice.lua`,
  `view/relic.lua`, `view/lights.lua`, `tools/shots/relic_slice.lua` (styles mode); tests `tests/lua/language_spec.lua`
