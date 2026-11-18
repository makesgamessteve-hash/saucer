# mod-browser Specification

## Purpose
A mod browser on the title card and the bed lists the base game and every mod with its version and whether it loaded.

## Requirements

### Requirement: The mod browser
The title card and the bed SHALL offer a mod browser listing the base game and every folder in the mods directory with its name, version, description and whether it loaded (or why not: API, dependency, cycle). Choosing a mod SHALL switch it off or on from the next start, saved to `<user-dir>/mods.txt`; the rows SHALL show a pending change ("[on->off]", "[off->on]"). Changes SHALL never apply to a running game, never come from a replay, and `--mods` on the command line SHALL take precedence.

#### Scenario: Switch a mod off
- **WHEN** a player switches Bigger Tractor off and starts the game again
- **THEN** Bigger Tractor is not loaded and the browser lists it as switched off
