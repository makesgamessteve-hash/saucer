# mod-loading Specification

## Purpose
Mods load in a defined order, run in a script sandbox, declare an API version and declare their asset licences.

## Requirements

### Requirement: Load order and override
The engine SHALL mount `data/base` first and then enabled mods in dependency order (ties broken alphabetically by id), and a file at the same VFS path in a later mod SHALL override the earlier one.

#### Scenario: Mod overrides a sound
- **WHEN** mod `loud_shrink` contains `sounds/shrink.wav` and depends on `base`
- **THEN** playing `sounds/shrink.wav` plays the mod's file

#### Scenario: Dependency cycle
- **WHEN** mod A depends on B and B depends on A
- **THEN** neither loads, and the mod screen shows the cycle

### Requirement: Script sandbox
Mod Lua SHALL run without access to `io`, `os.execute`, `package.loadlib`, binary chunk loading, or `debug`, and SHALL access files only through `saucer.vfs` and `saucer.save`.

#### Scenario: Forbidden call
- **WHEN** a mod script calls `io.open("x")`
- **THEN** a Lua error naming the mod is raised and logged, and the game keeps running

### Requirement: API versioning
The engine SHALL refuse to load a mod whose manifest `api` major version differs from the engine's, and SHALL show the reason.

#### Scenario: Old mod
- **WHEN** a mod declares `api = 0` on an engine with API 1
- **THEN** the mod is skipped and listed as "incompatible API 0 (engine 1)"

### Requirement: Mods declare asset licenses
A mod manifest SHALL declare `licenses = { code = ..., assets = {...} }` using SPDX IDs (including `LicenseRef-*`). The engine SHALL load assets without a sidecar `license` field, but SHALL log a warning and mark the mod "unlicensed assets" on the mod screen. The credits screen SHALL list every mounted mod grouped by license class.

#### Scenario: Unlicensed sprite in a user mod
- **WHEN** a user mod contains a sprite whose sidecar has no `license`
- **THEN** the sprite loads, a warning names it, and the mod screen shows "unlicensed assets"
