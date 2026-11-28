## Why

Steve asked to rearrange the saucer interior, add decoration, cooking, plants,
pets and a bigger-on-the-inside corridor (t69u), then approved the plan as
written (t73u). This is phase 1: each saucer gets its own layout, edit mode
moves built-in furniture as well as bought pieces, placement gains wall, on-top
and ceiling kinds, a reachability check keeps stations walkable, and a docked
guest may do the same home-life acts as the host. Ship systems stay host-only.

## What Changes

- ADDED `home-decor`: Edit mode
- ADDED `home-decor`: Built-in furniture is movable
- ADDED `home-decor`: Wall, on-top and ceiling placement
- ADDED `home-decor`: Reachability
- ADDED `home-decor`: Undo
- MODIFIED `home-decor`: Guests in a decorated dome (full home-life access; goods stay in the house)
- ADDED `coop-local`: Guest home-life in a host's Villa
- ADDED `player-input`: Edit and undo actions
- ADDED `saucer-interior`: Layout resolved per saucer
- MODIFIED `save-system`: State version 25; a lazy `p.home` table; edit carry is not saved

New scripts: `sim/layout.lua`, `sim/walkgrid.lua`, `sim/homeedit.lua`.
New tests: `tests/lua/layout_spec.lua`, `tests/lua/walkgrid_spec.lua`,
`tests/lua/homeedit_spec.lua`, `tests/game/homeedit.lua`.
Movable built-ins gain stable ids in `saucer/interior.lua`. Bought furniture
gains `place` kinds; a wall print, hanging lamp and desk figurine are added.
Interior group meshes rebuild per layout revision when something has moved.
Seed-42 slice and co-op replays are re-recorded for VERSION 25.

## Impact

- Extends `home-decor`, `saucer-interior`, `coop-local`, `player-input`, `save-system`
- State VERSION 25 (replays re-recorded). Games that never enter edit mode
  create no `p.home` table, so only the version field changes their hashes.
- `layout.of(p)` returns the base layout table unchanged when there are no
  overrides, so existing tests keep the same collision.
- Touch screens enter and leave edit mode from the Home planner (no changes
  to `sx_touch.c` or `web/shell.html`).
- Room-plan presets, the bigger garden, the galley, new decor sources, the
  Fold Annex and pets are later phases of the same plan.
