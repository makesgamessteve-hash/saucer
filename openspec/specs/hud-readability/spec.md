# hud-readability Specification

## Purpose
The HUD keeps messages, alerts and mode hints readable on every screen size.

## Requirements

### Requirement: Message log readability
HUD messages SHALL wrap to the view's width, two lines each at most, fold repeats into "(xN)" and show the most urgent first: locks, Clamps, the Warden and Fold Retreats in red, advice in amber.

#### Scenario: A danger-3 pile-up
- **WHEN** a Clamp warning, the Warden's sighting and two repeats of a pickup arrive together at 1280x720
- **THEN** every line fits on screen, the Warden line comes first and the repeat reads "(x2)"

### Requirement: Centre alert stack
The centre alerts SHALL be one stack, most urgent on top: Clamp, Snatcher, lock or Warden, alert.

#### Scenario: Clamped and latched
- **WHEN** a Clamp and a Snatcher hold the same saucer
- **THEN** the Clamp line sits above the Snatcher line

### Requirement: Mode hints
Control hints SHALL be those of the current mode (helm, walking the saucer, on foot in a derelict, in a station), shown for a while after the mode changes. On foot nothing SHALL be drawn over the coin and suit lines.

#### Scenario: Leaving the helm
- **WHEN** a player stands up from the helm
- **THEN** the walking hints replace the flying hints
