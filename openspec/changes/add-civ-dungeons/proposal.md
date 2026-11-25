## Why

Steve asked for relics you get lost in, and for stations that look different depending on the civilization that
built them. `add-relic-dungeons` made the slice's Vyrr relic a warren of halls, corridors, shafts and Seat chambers
round a heart hall. With every civ now owning a design language (`add-design-language`), the room graph itself
should change with the builder, not just the skin (design civs-and-relics §3.2, plan phase 6).

## What Changes

- **Room grammars** (`civs/dungeons.lua`): each massing archetype overrides the relic kit's warren: organism
  (a long, branching gullet with few loops), lattice (a dense grid with many loops and square halls), shell
  (wide nested rings), ring (a hollow square of halls, the inside empty), helix (a narrow footprint over six levels),
  hive (a dense foam of small halls), cluster (modules on long corridors) and spine (one long axis with wings).
- **Body scale**: tiny bodies get small halls and a smaller heart (still at least the 128 m Core), giant and colossal
  bodies the big halls, a bigger heart and fewer Seat chambers; levels sit far enough apart for 20 m shafts.
- `relicgen.styled(kit, civ)` builds (and memoizes) the restyled kit; a ring mask keeps the lattice's inside empty
  while the main way still reaches the heart. Styled relics may take up to 16 tries.
- **The slice is unchanged**: the Vyrr pin `layout = "warren"`, so its relic, goldens and replays stay the same.
  Relics of other civs only appear once relics enter normal play (plan phase 8), so no state or replay changes.
- `tools/maps/`: top-down maps of a relic in every archetype.
- Not in this change (later, same id): per-civ heart machines, landmarks per big hall, radar outlines of visited rooms.

## Impact

- Specs: `relic-stations` (ADDED: civ room grammars)
- Code: `civs/dungeons.lua`, `sim/relicgen.lua`, `civs/relic_slice.lua`, `tools/maps/`; tests
  `tests/lua/civdungeon_spec.lua`
