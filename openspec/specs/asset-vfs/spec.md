# asset-vfs Specification

## Purpose
The game finds its assets beside the binary and shows an error texture instead of failing when one is missing.

## Requirements

### Requirement: Assets beside the binary
The engine SHALL load all gameplay scripts, models, textures, sprites, sounds, and music from the `data/` and `mods/` folders beside the executable (or the served web root), and SHALL NOT embed game content in the binary other than a fallback font, error texture, and error mesh.

#### Scenario: Missing texture
- **WHEN** a model references a texture path that doesn't exist in the VFS
- **THEN** the engine logs a warning naming the path and renders the error texture

#### Scenario: Web build
- **WHEN** the web build starts
- **THEN** it fetches `data/index.json` and loads assets over HTTP on demand, with no preloaded data bundle
