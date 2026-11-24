## Why

Steve asked for the alien stations to be more alien, and bigger. The megastructure stations from
add-huge-stations read as human space stations (a visitor arm, a hub drum, spinning rings on spokes, solar
wings, cargo racks), and at about a kilometre the hangar cell was still a visible part of them.

## What Changes

- **Alien architecture families.** Every trader station is grown by one of four families picked from its
  seed (`sim/stationhull.lua`, kit data in `station/hull.lua`):
  - **Reef (coral)**: a coral trunk with chitin plates and glowing pores, bending tendrils ending in glowing
    polyps, habitat bulbs, and a halo of drifting spores.
  - **Lattice (crystal)**: a cut-crystal core in a lattice of nodes and struts, great shards with
    siblings at their feet, and a halo of floating splinters.
  - **Helix (spiral)**: a long horn, a nautilus of growing chambers, and two or three lopsided, flaring
    helices of nodules that turn round it.
  - **Gyre (shells)**: a great orb with irises, nested shells of rings and plates turning on tilted axes,
    standing stones, and a tail of smaller orbs.
- **Shared alien pieces.** Each family shapes the stem out of the hangar cell and the docking pods (polyps,
  cut crystals, cocoons, orbs) with glowing iris mouths. Every station also has floating glyph monoliths,
  cocoon clusters, pulsing conduits, an alphabet of alien glyphs on the signs, alien palettes (chitin,
  coral, verdigris, obsidian, nacre, glacier, amber) and coloured beacons that pulse.
- **Bigger.** A port is now about 2.0–2.6 km long and 1.8–2.1 km across, about twice the old size on
  every axis. An outpost is a quarter of a port's size, about twice the old outpost.
- **Placement.** `sector.place_station` tests the hull's bounding box against every site, the vault and the
  arrival point, keeping at least 120 m of room. It places the dock anchor as near the start as it can,
  and keeps the way in from the arrival point to the hangar mouth clear of the hull.
- **An alien wing inside.** Off the market's far wall, the walkable station grows a wing of 4–8 chambers
  and the passages between them. Some passages are straight and some dogleg, and ribs arch askew inside
  them. The chambers come in five looks:
  - atriums with growth pillars, a glowing pool and orbiting lights
  - vertical shafts 36–54 m tall, with ledges climbing the walls and a floating monolith
  - brood halls with cocoon racks
  - glowing gardens
  - glyph shrines with an altar and a floating monolith

  The wing's walls are organic (half-sunk growths and glowing veins). Chambers are named and coloured by
  the family and have their own lamp colours, and shafts get lamps all the way up their walls. The wing
  draws from its own random stream, so the concourse, market, bar and hangars are as they were.
- **Walk-in seed per sector.** Far sectors' walk-in seeds now include the sector, so their stations differ
  in family and wing. The home sector's seeds are the same as before.
- The concourse nav graph takes stops only from the concourse's own doorways. A strut rod's pitch was
  mirrored; that is fixed. Walk queries look solids up in a coarse grid and try nav nodes nearest first
  (same answers, about nine times faster on the bigger layouts).
- State version 19 (the trader, the far hangar and the walk-in layout move); the seed-42 slice and co-op
  replays are re-recorded.

## Impact

- ADDED capability `alien-stations`.
- Code:
  - `sim/stationhull.lua`, `station/hull.lua`, `view/stationhull.lua`
  - `sim/stationgen.lua`, `kits/station.lua`, `view/station.lua`, `view/lights.lua` (station lamps only)
  - `sim/sector.lua`
- Tests:
  - `tests/lua/stationhull_spec.lua`, `tests/lua/alienwing_spec.lua`, `tests/game/alien.lua`
  - tools: `tools/shots/alien.lua`, `tools/shots/alien_bench.lua`, `tools/shots/alien_perf.lua`
- The spinning layer (spore halos, splinter halos, helices, shells) has no collision.
