## Why

Steve liked the new lighting and wants more mood: interiors dark enough that the saucer's own
headlights and floods matter, and light you can see in the air (headlight beams, a glow round lamps),
while staying playable and cheap enough for the web.

## What Changes

- ADDED `retro-renderer`: in-air light (haze). A few lights per view glow in the air: point lights
  as a soft halo, spots as a visible cone, integrated per pixel along the eye ray up to the surface (so
  walls cut the beams). Budget by preset: high 4 lights with 8 cone samples, low 2 with 4, off none;
  a three or four way split screen keeps 2 and 4. `view:light{haze=}`, `view:lighting{haze=}`,
  `saucer.render.lights(view)` reports `haze`, `haze_steps`, `glow`.
- ADDED: dark interiors. A derelict's rooms are lit by one to three low pools along their walls with
  darkness between them, and one room in three has no lamp; a city's rooms are all lit, with more and
  brighter pools. Every placed lamp (rooms, bays, stations, Watchers) goes through one global dimmer
  (`LAMP_SCALE`) in `view/lights.lua`; the saucer's cabin lamps are not dimmed and do not glow.
- Headlights glow most, the floods faintly (they light the room for orientation without greying the air).
- Render only: no state version change, the replays stand.
