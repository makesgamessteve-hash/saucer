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

### Requirement: Light sources
Each view SHALL be lit by a list of sun, point and spot lights submitted per frame, each with a colour and intensity; point and spot light SHALL fall off by the inverse square with a soft source and fade to nothing at their range. The ambient light SHALL stay low and the result SHALL be exposed and tonemapped. Up to 16 lights SHALL shade a view (8 on the low preset or in a three or four way split screen), the strongest at the eye first.

#### Scenario: A far lamp is dropped
- **WHEN** a point light lies more than 150 m beyond its range from the eye
- **THEN** it is not among the view's active lights

#### Scenario: A full list
- **WHEN** more than 96 lights are submitted to one view in a frame
- **THEN** the extra lights are counted as dropped and the frame still renders

### Requirement: The star is the light outside
Outside, each sector's star (its colour and direction fixed by the seed and the sector) SHALL be the first and dominant light and SHALL cast shadows through fitted cascades. Inside a derelict, a city, a station or a hangar bay no sunlight SHALL reach; only the place's own coloured lamps SHALL light it.

#### Scenario: Sun first
- **WHEN** the saucer hovers outside a derelict
- **THEN** the first active light is the sun and at least one shadow cascade is in use

#### Scenario: No sun inside
- **WHEN** the saucer is inside a derelict hall or the hangar bay
- **THEN** no sun is active and point lamps light the room

### Requirement: Shadow quality presets
Shadows SHALL be drawn into one depth atlas: sun cascades, spot maps and cube maps for the strongest point lights. Presets off, low and high SHALL set the atlas size and the number of maps (`--shadows`, `saucer.render.settings{shadows=}`), low being the default on the web. A three or four way split screen SHALL keep one sun cascade and one spot map per view and no cube maps.

#### Scenario: Shadows off
- **WHEN** the shadow preset is off
- **THEN** no shadow maps are drawn and the lights still shade the scene

#### Scenario: Four views
- **WHEN** four players share the screen on the high preset
- **THEN** each view uses at most one cascade and one spot map, and no cube map

### Requirement: Light in the air
A few of a view's lights SHALL glow in the air: a point light as a soft halo, a spot as a visible cone, accumulated along the eye ray and ending at the first surface so walls cut the beams. The sun SHALL never glow. The high preset SHALL allow 4 glowing lights, low 2 with a cheaper cone, off none; a three or four way split screen SHALL allow at most 2.

#### Scenario: Headlight beams
- **WHEN** the headlights are on in a dark derelict hall on the high preset
- **THEN** at least one glowing light is reported for the view and the beams show in the air

#### Scenario: Off preset
- **WHEN** the shadow preset is off
- **THEN** no light glows in the air

### Requirement: Dark interiors
Inside a derelict, its lamps SHALL light pools with darkness between them and some rooms SHALL have no lamp, so the saucer's headlights and floods are needed to see; a city's rooms SHALL all have lamps. Every placed lamp SHALL be scaled by one global dimmer; the saucer's cabin lamps SHALL not be dimmed.

#### Scenario: A dark room
- **WHEN** the lamps of a sector's derelicts are generated
- **THEN** at least one room has no lamp and most rooms have one to three

#### Scenario: Floods to orient
- **WHEN** the floods are switched on inside a dark hall
- **THEN** an all-round saucer light lights the room around the saucer
