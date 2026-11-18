# Change: Presentation and packaging (roadmap milestone 6)

## Why
Milestone 6 of `docs/ROADMAP.md`: "It looks and ships like the retro-3D
game in the concept." The game played well but looked flat (untextured
interiors, plain station walls, no crowd, two nebula sprites for a sky),
was nearly silent, had only smooth turning in VR and no way to get a
build without compiling it.

## What Changes
- **Art pass (Grok Imagine).** 17 new generated sources in
  `art/src/generated/` (logged in `art/prompts/log.jsonl` with xAI output
  terms) are downscaled and quantized by `tools/artpipe` into 23 retro
  textures and four new palettes (`interior`, `kits`, `sky`, `sprites`):
  wood, fabric, tile, floor, metal and panel materials for the Villa;
  floor textures for the starship, station and city kits; a station hall
  wall; nebula, planet and galaxy backdrops; four folk sprites; shop and
  bar signs; glyph decals and the title emblem.
- **Where the art goes.** Villa parts carry a material (`meshes/interior.lua`)
  and are drawn per material (`assets.split_mats`). Derelict floor slabs get
  the kit floor texture and big rooms get glyph inscriptions. The station
  has textured walls, floor and ceiling, a crowd of folk sprites per area
  and signs above the stalls and the bar. The sky has a second nebula, a
  planet and a galaxy. The title panel shows the emblem.
- **Audio pass.** 13 new sounds synthesized by `artpipe` (code-generated,
  no samples: the synth code is MIT, the rendered sounds CC BY 4.0): five loops (engine hum, beam, holodeck,
  station, derelict) and door, scan, jam, alert, locked, hit, click and
  coin one-shots. The engine gains looping voices with handles
  (`saucer.audio.play(path, {loop = true})`, `saucer.audio.set`,
  `saucer.audio.stop`). `view/audio.lua` plays the sim's fx, hears doors,
  panel clicks and the pocket coin, and fades the loops from what the
  player is doing.
- **WebXR comfort.** Snap turning (default on): the engine's comfort filter
  turns a right-stick flick into one tick of the new `snap_left` /
  `snap_right` actions and the sim turns 30 degrees for each (so replays
  stay exact); smooth turning when it is off. A comfort vignette closes in
  while the view moves or turns smoothly. Seated sessions use the `local`
  space at the cockpit eye; standing sessions use `local-floor` with the
  cockpit lowered by the eye height. The web shell offers "VR seated" and
  "VR standing".
- **Diegetic controls in XR.** The flat HUD is off in the headset, so the
  tracked controllers are drawn as hands and the left wrist carries a panel
  with charge, hold and beam-lock bars. The size lever stays on the right
  grip and stick.
- **Touch polish.** Near misses on buttons still press them, held widgets
  light up, labels are centred and short, the stick shows a floating ring
  and knob, the lift slider shows its level and button presses vibrate on
  phones that support it.
- **Packaging.** `.github/workflows/release.yml` builds a Windows zip
  (windows-msvc), a Linux tarball and a web zip on a `v*` tag, smoke-tests
  them and attaches them to the GitHub Release. v0.1.0 is the first one.

## Impact
- Affected specs: art-presentation, audio-presentation, xr-comfort,
  touch-controls, release-packaging
- Affected code: `tools/artpipe/artpipe.py`, `art/`, `data/base/generated/`,
  `data/base/authored/{palettes,sounds}/`, `data/base/meshes/interior.lua`,
  `data/base/scripts/view/{assets,render,station,hud,audio,xr}.lua`,
  `data/base/scripts/sim/{comfort,flight,game,holo,visit}.lua`,
  `data/base/input/default.lua`, `engine/src/core/{sx_xr,sx_touch,sx_script,sx_engine}.{c,h}`,
  `engine/src/platform/{sx_audio,sx_gl,sx_sdl_main}.c`, `web/`,
  `.github/workflows/release.yml`
- Determinism: art, audio, the vignette, hands and touch drawing are render
  only. Snap turns are ordinary commands (two buttons appended to the
  button order), so existing replays keep their hashes.
