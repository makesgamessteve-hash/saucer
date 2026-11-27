## Why

Steve asked whether the "city on a planet" was really on a planet, then asked to implement auto-generated real planets with a planet-like surface. Today a body city (planet, moon or asteroid) is a flat grid of lots and a megacity ring floating in a starfield. The only drawn planet is a camera-locked ringed-gas-giant billboard in the sky, which never gets closer. There is no globe, no terrain around the city, and from below the city is a thin slab over stars.

## What Changes

- **A seeded body** (`sim/planet.lua`) under every body city, derived from the city's seed (nothing new is saved):
  - a sphere whose radius is drawn from a range for that body (planet ~100-140 km, moon ~50-80 km, asteroid ~24-34 km)
  - the city's street is tangent to the sphere, and a rim around the megacity is flattened so the existing lots sit flush
  - a height and colour function (oceans, coasts, highlands and ice on a planet; maria and craters on a moon; rocky ground on an asteroid)
- **The sector heart stays in space.** Other sites, the trader station and the arrival point sit in an open bay toward the origin; the body wraps the sides and the far side of the city.
- **View** (`view/planet.lua`): a smooth spherical globe (tessellated patches on the sphere, a soft atmosphere rim), a smooth terrain cap around the city, and a faint atmosphere on a planet. Drawn behind the city and in front of the stars. The camera-locked sky billboard is hidden in a sector that already has a planet body (a moon keeps it as a distant companion).
- **Air, landing and collision.** The body's air (fog, day and night) holds over the cap. Outside the city rim the surface can be landed on, and the hull will not sink through it. Under the city the existing lots and the warren are unchanged; a crust starts below the warren.
- **Concentric cities.** Planet, moon and asteroid cities are planned as a big centre (a plaza and the tallest towers) with ring-districts outward (civic, market, residential, industrial/port) and radial avenues. Corner lots of the old square grid are dropped so the footprint is a disk. The megacity's outer districts form an annulus around that core, not a square. Lots, the warren, landing, traffic and missions keep working.
- Visual first: not a detailed terrain sim, just enough to read as a planet from space and as ground around the city. The globe's limb is smooth, not faceted.

## Impact

- Specs: `cities` (ADDED: generated planet bodies)
- Code: `sim/planet.lua`, `view/planet.lua` (new); `sim/game.lua`, `sim/landing.lua`, `view/render.lua`; shot script `tools/shots/planets.lua`
- Tests: `tests/lua/planet_spec.lua` (new)
- State version 24: concentric city plans change the rooms and lots of a seed; both seed-42 replays are re-recorded.
