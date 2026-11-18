# Change: Detail pass for the saucer and the alien structures (v0.7)

## Why
The 3D pass made the world huge, but the rooms and hulls looked bare: flat
boxes with a few lights. The owner asked to "add details to the saucer and
to the alien structures".

## What Changes
- Villa interior props (`saucer/decor.lua`, `meshes/props.lua`): a stove,
  sink, cabinets and a fridge in the kitchen; cushions, a lamp, shelves and
  plants in the living room; bed dressing, a lamp and a painting in the
  bedroom; a basin, mirror, towels and tiles in the bathroom; jars and
  crates in the lab. All of it is decor only and never collides.
- Villa structure (`meshes/interior.lua`): railings with balusters, lit
  stair nosings and handrails, dome struts with a ring brace and lit hub,
  baseboards, cove lights, pilasters and ceiling ribs.
- Engine room machinery: the engine ring, pipes, tanks and battery bars,
  plus two counter-spinning rotors and two pistons animated from the render
  tick (`view/render.lua`).
- Hull detail (`meshes/saucer.lua`): panel seams, a light row, antennas, a
  dish, docking lights, vents and thruster nozzles with a glow sprite. The
  Seat gets fins and a rear thruster.
- Derelict detail (`view/detail.lua`): wall panels, pipes, lit strips,
  glyph decals, hatch rims, beams, cables, torn sections, floating debris
  and floor props (crates, machines, consoles, barrels, pods, bunks,
  planters, fountains, obelisks) per kit style. City plazas get lit paths,
  benches and overgrowth. Exterior solids get window grids, ledges, roof
  gardens and tanks (towers), X bracing and solar wings (trusses) and ribs
  and nozzles (spines). Cities get sky bridges between nearby towers.
- Per-kit textures (`kit_starship`, `kit_station`, `kit_city`, generated
  source art run through artpipe) for walls and solids.
- Budgets and performance: every room, solid and link set has a part
  budget. Detail meshes are built lazily per chunk (at most 6 per frame),
  drawn only within 480 m and culled with their chunk. Far saucers skip
  their interior beyond 260 m.

## Impact
- Affected specs: saucer-detail, derelict-detail
- Affected code: `data/base/saucer/decor.lua` (new),
  `data/base/meshes/{props,interior,saucer}.lua`,
  `data/base/scripts/view/{detail,assets,render}.lua`, `data/base/kits/*.lua`,
  `tools/artpipe/artpipe.py`, `art/src/generated/kit_*`
- Determinism: visual only. Detail is seeded from the ruin seed and room
  id, never touches sim state, and the sim version, save format and replay
  hashes are unchanged.
