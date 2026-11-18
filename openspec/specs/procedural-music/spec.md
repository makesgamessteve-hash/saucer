# procedural-music Specification

## Purpose
Each civilization has its own procedurally generated music.

## Requirements

### Requirement: Civilization music
The game SHALL play music made at runtime from four code-generated notes pitched to the civilization's scale and root at its tempo: sparse pads in open space (the sector's first civilization), the site civilization's voice over a bass line inside a derelict, and a double-time pulse when a sentry alert is on. The music SHALL be render-side only and SHALL never change the simulation.

#### Scenario: Inside a derelict
- **WHEN** a player flies into a site of a civilization with a pentatonic scale
- **THEN** the notes played are pitched to that scale and its tempo, and the state hash is unchanged
