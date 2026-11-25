## Why

Steve chose "distinct hull exteriors per civ" as the next piece of work after the alien cities. Today every trader
station is one of four architecture families picked by its seed, whoever built it, and a relic seen from outside its
near range is a few membrane blobs in the Vyrr's colours whatever civ built it. From 1.5 km a relic reads as a dark
silhouette. Two builders should read apart from far off: in silhouette, surface pattern, lighting and material.

## What Changes

- **A civ's hull dress** (`sim/hulldress.lua`, data `civs/hulls.lua`), a pure function of the civ and its roster:
  - silhouette: a motif of big growths (spines, fins, arches, domes, masts, cage, tendrils, shards). A roster hands
    them out in index order, each civ getting its massing's liking unless an earlier civ took it, so no two of a
    roster's first eight civs share one.
  - surface pattern: from the civ's signature rule (PIERCE studs, CRUST nodules, PLATE scales, INLAY lit lines,
    ENCASE hex cells, FLOW streaks).
  - material: the plating, trim and accent colours come from the civ's own material table (lifted so a dark
    material still reads), and the plating takes the civ's material slots where it is drawn.
  - lights: signal lights blink by the civ's light model (chromatic: colour cycles; echo: ripples down the hull;
    chemical: big soft breathing glows; field: arcs jumping between pairs; tidal: lights circling; touch: a faint
    rim glow only).
- **Stations wear their builder's dress.** A port is built by its sector's first site's civ, a city's outpost by the
  city's. The family's pick still draws its number, so the station's shape, box, placement and random stream are
  unchanged; the dress only adds:
  - a crown of the motif behind the body (a hub on the axis, elements radiating round it), smaller copies cresting
    the stem's top, all solid as drawn and well behind the hangar cell and its approach;
  - the pattern on the hub and on the body's surface spots;
  - signal lights on every tip, drawn out to 9 km and never smaller than 1.1% of their distance;
  - the far silhouette lights itself a little (and the crown a little up close), so a station far off reads in its
    colours.
  - When a relic of another civ holds the view's material slots, a station draws a plain twin of its meshes.
- **Relics seen from afar wear their builder's dress.** Each big room's far hull takes the civ's edge language
  (round lobes, eight-sided pods, fluted columns, stacked shards), in its plating colour, with a lit band, the civ's
  pattern on its flanks and its motif on its crown, plus signal lights on the crown tips. The far hulls and signals
  now draw out to 7 km (before: nothing past 2.4 km). The far hull used to always wear the Vyrr's colours.
- Fix: restyling relics (`view/relic.set_style`) frees the far hull meshes too (shot scripts ran out of meshes).

## Impact

- Affected specs: new capability `hull-exteriors`.
- Affected code: `sim/hulldress.lua` (new), `civs/hulls.lua` (new), `sim/stationhull.lua`, `view/stationhull.lua`,
  `view/relic.lua`, `station/hull.lua` (far budget 6000 -> 8000 triangles), `tools/shots/hulls.lua` (new),
  `tests/lua/civhulls_spec.lua` (new).
- No save or state changes: the dress is never saved, the sim's random streams are untouched, the station solids
  only gain boxes behind the hangar cell. Both replays play to the same hashes.
