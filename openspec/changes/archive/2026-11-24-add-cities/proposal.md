## Why

Steve asked for cities on asteroids, moons and planets, vast and interesting. Concept §3 and §7 already say
alien structures are huge and the saucer flies inside them; a city is that idea at its largest. This is
milestone 11 (`docs/ROADMAP.md`).

## What Changes

- Three new city kits (`city_planet`, `city_moon`, `city_asteroid`) and `sim/citygen.lua`, a seeded
  hierarchical generator (city, districts, blocks, buildings, tunnels and an undercity, towers, sky-bridges,
  landmark districts: spaceport, reactor heart with the vault, archive, foundry, garden arcology, palace).
- City sites in far sectors (sectors 2 to 4 hold one of each body), `CITY:<body>` tags on the sector map.
- A district power grid (`sim/cities.lua`): every district but the spaceport starts dark, with shut gates and
  sleeping sentries; its power coupling is beamed home to wake it and open its gates. Saved as lazy entries in
  `state.locks`.
- Body gravity: a planet's pull costs Charge to hover (the hangar refills it, a flat Charge never traps a hull),
  a moon's pull is light and an asteroid has none.
- A city map panel and HUD beacon; per-body air (planet fog with a day and night, moon earthlight, asteroid dark).
- Streaming at render time: per-district coarse meshes, culled chunks, a short detail range, a beam-sense limit on
  the loot rolled each tick; the engine mesh table grows from 1024 to 4096 handles.
- Tests, a game test, screenshots and a frame-time measurement (`tools/shots/cities*.{lua,sh}`).

## Impact

- New capability `cities`. Replays are unchanged (the city is an extra site from its own seed stream; state is
  lazy), so `game.VERSION` stays 10.
- Not built (see `docs/ROADMAP.md` milestone 11): true lazy district generation, transit rails and canals,
  collapsing structures and storms as dynamics, a flooded undercity, mystery tie-ins, on-foot hand-locks for the
  grid, trader stations near cities.
