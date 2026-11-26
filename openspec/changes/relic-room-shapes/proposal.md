## Why

Steve liked the new relic room plans but asked to take care that no two space stations of the same alien species
are alike ("that would become boring very fast"). The halls themselves were still boxes, and two relics of one
species could come out nearly identical (layout distance 0.02-0.05 under the metric below).

## What Changes

- **Room shapes** (`sim/relicshape.lua`): a patterned relic's halls take the shapes their pattern calls for:
  - arcs of the ring round the heart (rings, helix, spiral)
  - round or many-sided bubbles (shells, so a shell reads differently from a ring from above, and spiral)
  - diamonds (lattice), cut triangles (hive), crosses (cluster) and skewed parallelograms (spine)
  - chamfered octagons, as a fallback or second shape
  Each relic draws its own style from its seed: the main shape, a second shape mixed in, the share of plain
  halls, and the shape parameters. The maw's hall, the lung, the plague hall and the heart keep their boxes.
- Every door keeps a channel to the hall's centre and the centre stays clear, so the autopilot's door -> centre ->
  door way never meets the solid.
- **Collision**: the box outside the shape is filled with solid strips (4 m cells, merged), `ruin.fill`, which goes
  into physics. A cell is solid only if its centre or one of its corners is outside the shape.
- **View**: the shape's wall is drawn along a 2 m marching-squares contour as yawed slabs on the solid side, with
  glowing seams at the floor and ceiling. Hall lamps hang over free floor.
- **Map**: the helm's relic map and `tools/maps/` draw the shape (contour and free floor).
- **Systems in shaped halls**: loot finds, phenomena, Watchers and their power cells, Spotter squares, stealth
  cover pillars and guarded finds all sit over free floor (`relicshape.settle`, clear of floor hatches).
- **Per-station variation**: `sim/relicpat.lua` draws each relic's own pattern parameters (turn, mirror, drop,
  spurs, cap, pitch spread, and pattern-specific radii/depths/lengths). The helix ring path is now a proper
  4-adjacent perimeter.
- **Uniqueness guarantee** (`sim/relicsig.lua`, `sim/relicgen.lua`, `sim/sector.lua`):
  - signature: the room plan from above, every space but the heart, rasterized at 8 m centred on the heart
  - distance: 1 - IoU, minimised over the eight turns and mirrors
  - every relic site lists its species' earlier relics (`siblings`, in sector order); the generator redraws the
    relic (up to 64 seed children) until it is at least `MIN_DIST` (0.25) from each of them
- State version 22 (relic layouts change for the same seed); seed-42 slice and co-op replays re-recorded.

## Impact

- Specs: `relic-stations` (ADDED: relic room shapes; no two relics of a species alike)
- Code: `sim/relicshape.lua`, `sim/relicsig.lua` (new); `sim/relicgen.lua`, `sim/relicpat.lua`, `sim/ruin.lua`,
  `sim/sector.lua`, `sim/game.lua`, `sim/relicloot.lua`, `sim/relicsentry.lua`, `sim/stealth.lua`,
  `view/relic.lua`, `view/relicmap.lua`; tools `tools/maps/`, `tools/relicunique/`
- Tests: `tests/lua/relicshape_spec.lua`, `tests/lua/relicunique_spec.lua` (new), `tests/lua/funfixes_spec.lua`
