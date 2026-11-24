## Why
Phase 1 (add-cities) put cities in the game: they read as vast in scale, but the buildings were plain grey boxes and 9-16 districts is not yet "vast". Phase 2 makes the cities look like places that belong to somebody, makes them bigger, gives them transit and weather, and ties them into the mystery.

## What Changes
- Slice 1, look and lights: per-civ silhouettes (ziggurats, spires, domes, arcologies, inverted asteroid towers) whose collision equals what is drawn; civ light colours; window patterns, lit signs, ledges, roof greebles; per-district lights that come on, with a flicker and a ramp, when the grid is restored; landmark light pillars; the helm hint moved clear of the console and the alerts.
- Later slices (see tasks.md): a vast outer ring and horizon impostors, transit, a flooded undercity, storms, collapses, dark patrols, archive clues, traders.

## Impact
Sim: `sim/citygen.lua` (style, tiers), `sim/cities.lua` (`light`). View: `view/assets.lua`, `view/render.lua`, `view/hud.lua`. Replays unchanged: a city is an extra site from its own seed, and light is a pure function of the tick and the existing power locks (no new state).
