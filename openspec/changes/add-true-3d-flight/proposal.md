# Change: True 3D flight and huge multi-level sites (v0.6)

## Why
Until now the saucer flew on a plane. Lift existed, but nothing used it:
derelicts were one floor deep, and the radar, the HUD and the sentries all
assumed a flat world. The owner asked for "true 3D": a saucer that flies up
and down, and alien ships, stations and cities that grow in every direction
and are huge.

## What Changes
- Six-axis flight (`sim/flight.lua`). Forward thrust follows the look yaw
  and pitch, so you fly where you look. Strafe, vertical lift along the
  hull's up axis (×0.8) and yaw are separate axes. Dampening brakes to a
  hover that holds altitude. Pitch is limited to ±1.45 rad, so you can look
  straight up or down a shaft.
- A visual bank of at most 0.18 rad leans the saucer into turns and strafes.
  The interior is locked to the saucer frame, so the hull, the rooms and the
  pilot's eye all bank together. The deck stays level otherwise ("gravity
  plating"). There is no bank in XR or during a fold.
- Inputs: Space/Ctrl or R/Z for up and down on the keyboard, the gamepad
  triggers, the touch lift slider plus new "up" and "dn" hold buttons above
  and below it, and the right stick's vertical axis in WebXR. Mouse look
  pitches the flight path. In XR the flight path follows the stick look,
  not the head.
- Engine: a uniform-grid broadphase for physics queries, so huge sites stay
  cheap. Its results equal brute force, with ties broken by the lowest id.
  The camera gains a roll, and meshes take pitch and roll (`view:mesh`
  options, `sx_mat4_model_ypr`).
- Generator (`sim/ruin.lua`): rooms attach on all six faces. Floor and
  ceiling hatches join rooms on different levels, and shafts rise or drop
  many levels. Kits set the grid, a minimum vertical span and a minimum
  number of levels. Exterior solids (ship spines, station trusses, city
  towers) make the silhouettes huge. A new `city` kit is added. When every
  try fails, the fallback is a hand-placed three-level layout. Generation is
  pure and memoized.
- The sector places the three sites at different heights, 1.3–1.6 km out.
- Helm and HUD: a 3D radar floating over the desk shows contacts on stalks
  above and below the disc. There is an altitude tape with vertical speed,
  "UP/DN n m" elevation cues to the target, and the nearest site is measured
  by bounds distance.
- Sentries: Watchers look along the hatch axis, and shaft Watchers sit at
  the top looking down. Line of sight and cones use pitch. Snatchers patrol
  the longest axis, including vertical chutes. Scanner, jammer, mystery
  steps and cache drops use full 3D distances.
- Autopilot: routes go through hatches. A sky lane climbs over anything in
  the way.
- Render: per-room chunks, frustum-cone culling, a far LOD silhouette beyond
  1100 m, culling beyond 3200 m, and fog. Exteriors get window rows, belly
  lights and beacons.

## Impact
- Affected specs: saucer-flight-3d, ruin-generation-3d, derelict-play-3d
- Affected code: `engine/src/core/sx_{phys,render,script,touch}.{c,h}`,
  `data/base/scripts/sim/{flight,ship,ruin,sector,game,save,sentry,autopilot}.lua`,
  `data/base/scripts/view/{render,hud,assets}.lua`, `data/base/kits/*.lua`
  (new `city.lua`), `saucer/configs.lua`, `sentries/sentries.lua`
- Determinism: the sim version is now 5 and the save format is 2.
  `tests/replays/slice_seed42.srep` was re-recorded, and the layout known
  answers in `tests/lua/ruin_spec.lua` are new. The C known answers for RNG
  and math are unchanged.
