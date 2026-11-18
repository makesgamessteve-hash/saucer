# art-presentation Specification

## Purpose
Generated art goes through the retro pipeline so places and surfaces in the game look textured and consistent.

## Requirements

### Requirement: Generated art goes through the retro pipeline
Every generated texture SHALL come from a source image logged in `art/prompts/log.jsonl` with its tool, model, license and sidecar, and SHALL be downscaled and quantized by `tools/artpipe` into an index map with its palette. `artpipe lint` SHALL pass.

#### Scenario: Lint is clean
- **WHEN** `python3 tools/artpipe/artpipe.py lint` runs in CI
- **THEN** every asset has a sidecar with a license, every generated asset has a logged prompt, and the command succeeds

### Requirement: Textured places
The Villa interior SHALL draw its furniture, floors, walls and stairs with material textures. Derelict floors SHALL use the kit floor texture and big rooms SHALL carry glyph decals. The station SHALL have textured walls, floor and ceiling, signs over its stalls and bar and a crowd of folk sprites. The sky SHALL show nebulae, a planet and a galaxy, and the title panel SHALL show the emblem. All of it SHALL be render only.

#### Scenario: The art is loaded and drawn
- **WHEN** the assets are initialised and a frame is drawn
- **THEN** every art texture and palette is loaded, the sky draws its backdrops and the title panel draws the emblem

#### Scenario: The crowd does not touch the state
- **WHEN** a station frame is drawn twice
- **THEN** the crowd spots are the same both times and the simulation state hash is unchanged
