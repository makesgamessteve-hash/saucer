## 1. Language
- [x] 1.1 `civs/languages.lua` tables and `sim/language.lua` generator; every roster civ dressed in `civs.universe`
- [x] 1.2 Material table with one signature pairing from the odd-pair table, ring and decay materials
- [x] 1.3 Light model by senses; lamp colours and matcap from the materials and the model

## 2. Relics wear their civ's style
- [x] 2.1 Part colours, rib rhythm and the six signature rules in `view/relic.lua`; `set_style` for shots
- [x] 2.2 Lamps thinned and dimmed by the light model; ripple, orbit and arc motion in `view/lights.lua`
- [x] 2.3 The Vyrr dressed by the generator with its authored fields as pins
- [x] 2.4 `tools/shots/relic_slice.lua --script-arg styles`: the same relic in four civ styles

## 3. Verification
- [x] 3.1 `tests/lua/language_spec.lua`: every civ has a language, every rule drawn, echo civs use ripple lighting,
  skins never change envelopes, restyling, the Vyrr as the grammar's output

## 4. Later (same change id)
- [ ] 4.1 RADIAL / MIRROR / GROW / WARP on hall skins and apertures by language
- [ ] 4.2 Per-civ palette rows and style-card textures (offline), glyph strips, per-civ drone and room tone
