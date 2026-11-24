## Why

The relic design (`design/civs-and-relics.md` §1-§2) gives every civilization a design language and a material
palette, generated from the universe seed. The first relic slice (§9) needs only one civilization to build from,
so this change is scoped to that: one hard-seeded civ with the final record schema. Roster and history
generation stay for a later change under the same id.

## What Changes

- **The Vyrr** (`data/base/civs/relic_slice.lua`): a hard-seeded civ with the usual civ fields (name, body,
  shape, domains, fate plague, temperament, tint, glyph, music) plus the new language block (massing weights,
  edges, rhythm, senses, lamp colours) and material table (dominant membrane, accent chrome, rare amethyst,
  signature PIERCE: chrome through flesh, with a wound ring; decay materials).
- **Lookup.** `civs.by_id(nil, "vyrr")` returns it, and `civs.of(state, site)` returns it for a site that names
  it in `site.relic_civ`, so the Xenoarchive, item labels and music treat the Vyrr like any other civ. The
  generated roster is unchanged; no state or replay changes.

## Impact

- Specs: `civilizations` (ADDED: slice civ with language and materials)
- Code: `data/base/civs/relic_slice.lua`, `sim/civs.lua`
