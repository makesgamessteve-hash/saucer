## Why

The relic design (`design/civs-and-relics.md` §1-§2) gives every civilization a design language and a material
palette, generated from the universe seed. The first relic slice (§9) needs only one civilization to build from,
so this change first shipped that: one hard-seeded civ with the final record schema. The second part (task 3.1,
design §1 and §8.1) gives every universe a full roster: trait axes, a diversity guard, a generated history with
relations and conquest wings, names and scanner lore lines.

## What Changes

- **The Vyrr** (`data/base/civs/relic_slice.lua`): a hard-seeded civ with the usual civ fields (name, body,
  shape, domains, fate plague, temperament, tint, glyph, music) plus the new language block (massing weights,
  edges, rhythm, senses, lamp colours) and material table (dominant membrane, accent chrome, rare amethyst,
  signature PIERCE: chrome through flesh, with a wound ring; decay materials).
- **Lookup.** `civs.by_id(nil, "vyrr")` returns it, and `civs.of(state, site)` returns it for a site that names
  it in `site.relic_civ`, so the Xenoarchive, item labels and music treat the Vyrr like any other civ. The
  generated roster is unchanged; no state or replay changes.

- **Roster size.** `universe.roster_size` in `civs/traits.lua` (default 8, clamped 6-10); slots 1-2 stay Velari
  and Oquun.
- **Trait axes** (`sim/civroster.lua`): body scale, biology, senses, social structure, tech focus, values, fate,
  era, plus a massing archetype from the social structure. The legacy fields are drawn exactly as before and every
  axis is drawn from the values consistent with them, so the legacy fields are a function of the axes
  (`civroster.derive`) and existing universes keep their sites, kits, music and replays.
- **Diversity guard.** Up to 16 rejection-sampled tries, then a deterministic swap: at least 3 massings and 2 body
  scales per roster, no two civs sharing more than 3 axis values.
- **History** (`civs/history.lua`): an active span per civ on a 1 Myr axis, 5-7 beats, stations built, a named
  age; a relation (trade, war, alliance, tutelage, conquest) for every pair with overlapping spans; a conquered
  civ gets a wing share of 10-25% (`civs.wing` says which of its relics carry the conqueror's wing).
- **Names and lore.** An endonym from the civ's senses, a trader exonym ("the Bell-Lens Titans"), unique station
  names, and scanner lore lines (`civs.lore`).
- **Roster hash** (`civs.roster_hash`) over every civ's axes, names and the whole history.
- Not in this change: the hash is not folded into the state hash (the roster is a pure function of the seed, which
  the state hash already covers, and folding it would change both replays for no gain); the HUD still shows the
  legacy name; tutelage's language inheritance waits for `add-design-language`.

## Impact

- Specs: `civilizations` (ADDED: slice civ with language and materials)
- Code: `data/base/civs/relic_slice.lua`, `sim/civs.lua`, `sim/civroster.lua`, `civs/traits.lua`,
  `civs/history.lua`, `civs/civs.lua`; tests `tests/lua/civroster_spec.lua`. No state version change; replays unchanged.
