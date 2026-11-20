## Why

Steve asked for the space station to be changed: it should be so big that the hangar for the saucer is
only a tiny part of it, and it should be much more detailed. The old station was a 40 m ring with the
whole hangar bolted to it, so the bay was most of what you saw.

## What Changes

- **Megastructure hull.** Each trader station is a kilometre-scale, code-generated 3D structure
  (`sim/stationhull.lua`, kit data in `station/hull.lua`): a visitor arm to a hub drum, a spinning
  big ring (sometimes a second one) on spokes, an aft spine with thrusters, cargo racks and solar
  wings, radiator fins, habitat drums, docking-arm pods, masts with dishes, lit window rows, beacons
  and a few hundred greebles. Seeded and deterministic: the same seed and sector give the same station,
  and stations differ in size, palette, counts and the bay number.
- **The hangar is one bay among many.** The saucer's cell is a ~60 m box on the arm; the far hangar is
  a real docking pod far down the structure. The cell shell, pad, strips, cranes, crates, tanks, fuel
  lines and signs are part of the station mesh (`view/dock.lua` draws only the dynamic parts).
- **Dock tuning.** Longer reach and a wider bay: the beam captures from 160 m, the bay is 34 m
  half-wide and 24 m high; an approach corridor of guide lights runs 420 m out of the mouth with a chase
  of lights toward the bay.
- **Sector layout.** `sector.place_station` puts the trader where the whole hull clears the sites and the
  arrival; the trader position stays the dock anchor, so the economy's dock range and the bay offsets
  keep their meaning.
- **Interior.** The hangar floor and the concourse gain props: rail cranes, fuel lines, hose reels, lane
  markings, ships on cradles, a catwalk, a booth, bay signs, carts, vending machines, kiosks, ad panels,
  benches, planters, banners, skylights and drones.
- **Performance.** Three levels of detail by distance to the hull's bounding box (silhouette beyond
  1100 m, hull and rings, then trusses, greebles and windows within 380 m), static merged meshes per layer
  and a capped number of blinking beacon billboards.
- State version 15; both replays re-recorded.

## Impact

- ADDED capability `station-megastructure`.
- Code: `sim/stationhull.lua`, `station/hull.lua`, `view/stationhull.lua`, `sim/sector.lua`,
  `sim/dock.lua`, `sim/visit.lua`, `sim/stationgen.lua`, `view/station.lua`, `view/dock.lua`,
  `view/render.lua`, `lib/meshkit.lua`, `saucer/dock.lua`, `sim/game.lua`.
