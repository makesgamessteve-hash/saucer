# retro-renderer Specification

## Purpose
A low-resolution indexed-colour renderer with sprites and optional, XR-safe retro effects.

## Requirements

### Requirement: Low-res target
The renderer SHALL render each viewport to a configurable low-res target (default 480×270 on flat screens, 720×800 per eye in XR) and integer-upscale it with nearest filtering.

#### Scenario: Resolution change
- **WHEN** the internal resolution is set to 320×180
- **THEN** the frame is rendered at 320×180 and upscaled, and the sim state hash is unaffected

### Requirement: Indexed textures with palette LUT
Textures SHALL be loaded as 8-bit indexed images and colored through a palette LUT selected per material, so the same texture can be rendered with any civ palette.

#### Scenario: Palette swap
- **WHEN** a kit module's palette is changed from `vell` to `orun`
- **THEN** the same texture renders with the `orun` colors and no texture is reloaded

### Requirement: Sprites and billboards
The renderer SHALL draw Y-axis and camera-facing billboards with 1-bit alpha cutout, sorted correctly against opaque geometry.

#### Scenario: Loot item
- **WHEN** a loot item is spawned
- **THEN** it's drawn as a Y-axis billboard with its sprite, bobbing as defined in its Lua data

### Requirement: Retro effects are optional and XR-safe
Vertex snapping, affine warping, and dithering SHALL each be toggleable. Vertex snapping and affine warping SHALL be forced off during XR sessions.

#### Scenario: XR session starts
- **WHEN** a WebXR session begins with vertex snapping enabled in the flat-screen settings
- **THEN** vertex snapping is disabled for the XR views and restored when the session ends
