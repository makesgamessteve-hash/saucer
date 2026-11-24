## Why

Steve wants space to feel darker and exploring it to feel bounded: light should come from real
sources that cast shadows. In a star system the star lights the scene; inside an alien city, a
derelict or a station only the place's own coloured lamps do; and the saucer brings its own light:
cabin lamps in the Villa that can be switched off, headlights to look into the dark, and floods that
light all around so the player can find their bearings.

## What Changes

- ADDED `retro-renderer`: a per-view light list (sun, point, spot) submitted from Lua (`view:light`,
  `view:lighting`), inverse-square falloff with a soft source and a range window, colour and
  intensity, a low ambient, exposure and an exponential tonemap; the core picks up to 16 lights per
  view (8 on low or in a 3-4 way split screen), the sun first.
- ADDED `retro-renderer`: shadow maps in one depth atlas: two sun cascades, two spot maps (a saucer's
  headlight pair shares one), three cube (omni) maps for the strongest point lights, cached between
  frames in a single view; presets `--shadows off|low|high` and `saucer.render.settings{shadows=}`,
  low by default on the web; a 3-4 way split screen keeps one sun cascade and one spot map per view.
- ADDED: each sector's star (colour and direction from the seed) is the dominant light outside; inside a
  derelict, a city, a station or a hangar bay no sunlight reaches, only coloured point lamps placed per
  room by the generators (stations warm and white, alien places colourful, a city's dark grid stays dark).
- ADDED `saucer-interior`: the saucer's lights: cabin lamps per room (on by default), two
  shadow-casting headlight spots, an all-round flood under the hull; keys 4/5/6, one pad button
  (tap: headlights, or cabin lamps while walking the Villa; hold: floods); HUD state and help line.
- ADDED `sentries-and-tools`: headlights and floods add to the stealth signature (a Watcher reads a lit
  saucer sooner).
- State version 18; the seed-42 replays are re-recorded. Touch buttons for the lights come later.
