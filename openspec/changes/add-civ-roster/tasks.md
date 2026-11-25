## 1. Slice civ
- [x] 1.1 `civs/relic_slice.lua`: the Vyrr, the full civ record plus language and materials blocks
- [x] 1.2 `civs.by_id` and `civs.of` find it (`site.relic_civ`); the generated roster is untouched

## 2. Verification
- [x] 2.1 `tests/lua/materials_spec.lua` "are membrane (dominant), chrome (accent) and amethyst (rare), signed PIERCE"
- [x] 2.2 `tests/lua/relic_spec.lua` "adds the Vyrr relic only with the debug entry, and only once"

## 3. Later (same change id, after the slice)
- [x] 3.1 Roster size, trait axes, diversity, generated history, palimpsest wings (design §8.1)
- [x] 3.2 Names (endonym, exonym, station names) and scanner lore lines (design §1.4)
- [x] 3.3 `tests/lua/civroster_spec.lua`: default roster, legacy fields derive, 200-seed diversity, same seed same
  history, conquest adds wings
