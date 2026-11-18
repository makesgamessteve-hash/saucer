# art-pipeline Specification

## Purpose
Every art asset carries its licence and prompt record, generated and authored files stay apart, and the pipeline turns sources into the game's retro assets reproducibly.

## Requirements

### Requirement: License field on every asset
Every non-Lua asset under `data/` and in-repo `mods/` SHALL have a `.meta.lua` sidecar with a `license` field set to one of `MIT`, `CC-BY-4.0`, or `LicenseRef-xAI-Output`, plus a credit.

#### Scenario: Missing license
- **WHEN** a PR adds `authored/sounds/hum.ogg` with a sidecar that has no `license` field
- **THEN** the art lint job fails and names the file

### Requirement: Separated generated assets
Assets licensed `LicenseRef-xAI-Output` SHALL live only under `generated/` folders, and assets under `authored/` SHALL NOT carry a `generation` block or the xAI license. Atlases SHALL NOT mix license classes.

#### Scenario: Misfiled asset
- **WHEN** a generated sprite is committed under `authored/sprites/`
- **THEN** lint fails with "generated asset outside generated/"

### Requirement: Prompt record for every generated asset
Every generated asset's sidecar SHALL contain a `generation` block (`request_id`, `generation_id`, full prompt, template ID, style card, all params, model/version, date) that resolves to a matching entry in `art/prompts/log.jsonl`. Every generation request, accepted or rejected, SHALL have a log entry.

#### Scenario: No prompt record
- **WHEN** a PR adds `generated/textures/vell/hull_03.png` whose sidecar lacks `generation.prompt` or whose `request_id` isn't in the log
- **THEN** lint fails and names the missing field or ID

### Requirement: Reproducible processing
`tools/artpipe process` SHALL produce byte-identical output for the same raw image, palette, and settings, and `artpipe verify` SHALL re-process every raw file in `art/raw/` and compare the result to the sidecar's output hash.

#### Scenario: Tampered output
- **WHEN** a processed PNG is edited by hand without updating its sidecar
- **THEN** `artpipe verify` fails, reporting a hash mismatch

### Requirement: Palette and size conformance
Art lint SHALL reject textures whose dimensions aren't powers of two within the size limits in §11.2, and textures that aren't indexed, or that use colors outside their declared palette.

#### Scenario: Off-palette pixel
- **WHEN** a processed texture contains a color index outside its palette
- **THEN** lint fails and reports the first offending pixel

### Requirement: Generated licensing files
`ATTRIBUTION.md` (grouped by license class) and `REUSE.toml` SHALL be generated from the sidecars by `artpipe attrib`, and CI SHALL fail if the committed versions differ from freshly generated ones, or if `reuse lint` fails.

#### Scenario: Stale attribution
- **WHEN** a PR adds a CC BY sound without regenerating `ATTRIBUTION.md`
- **THEN** CI fails with a diff of the expected file

### Requirement: xAI terms reference
`LICENSES/LicenseRef-xAI-Output.md` SHALL contain at least one URL to xAI's terms for outputs, plus a retrieval date. Until it does, lint SHALL warn on PRs and the release job SHALL fail.

#### Scenario: Placeholder present
- **WHEN** a release build is triggered while the file still contains `TODO: link xAI terms`
- **THEN** the release job fails, and the message asks for the terms URL
