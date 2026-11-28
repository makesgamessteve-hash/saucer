## 1. Layout and data

- [x] 1.1 `sim/layout.lua`: lazy `p.home`, `layout.of(p)` (base table when there are no overrides), revision, moved built-ins, stations that follow a piece
- [x] 1.2 Stable `id` (and `station` where a Use spot should follow) on movable built-ins in `saucer/interior.lua`
- [x] 1.3 `place` kinds in `home/decor.lua` and three new pieces (wall print, hanging lamp, desk figurine) at the traders

## 2. Edit mode

- [x] 2.1 `sim/walkgrid.lua`: 0.25 m raster, flood fill from the stair foot, every station, door and the hatch stays reachable
- [x] 2.2 `sim/homeedit.lua`: enter/leave, pick, ghost, place, cancel, undo, 15° turns while Boost is held, same-tick tie-break, host-store pick-up for guests
- [x] 2.3 Input: `edit` and `undo` actions; the Home planner grows Enter / Leave / Undo rows; touch uses the planner
- [x] 2.4 Docked guests get home-life access in the whole Villa; helm, fold, tractor, lab, trade, hatch and sleep-and-save stay host-only

## 3. View and saves

- [x] 3.1 Group meshes rebuild per layout revision (dirty groups, one or more per frame); ghost tint; HUD edit prompt
- [x] 3.2 VERSION 25; `p.edit` is not saved (a carry is cancelled and the piece put back); `p.home` is created on first use
- [x] 3.3 Autopilot uses the walk raster when a layout override exists

## 4. Verification

- [x] 4.1 Lua specs `layout_spec`, `walkgrid_spec`, `homeedit_spec`
- [x] 4.2 Game test `tests/game/homeedit.lua` (and `--restore-every-tick`)
- [x] 4.3 Re-record `tests/replays/slice_seed42.srep` and `coop_seed42.srep`
- [x] 4.4 Coverage at least 95% for C and Lua; screenshot tour under `/workspace/saucer/shots_interior/p1/`
