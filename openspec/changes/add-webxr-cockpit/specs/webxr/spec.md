## ADDED Requirements

### Requirement: Enter XR from the web build
When `navigator.xr` supports `immersive-vr`, the web build SHALL offer an "Enter VR" control, and it SHALL start the session in the dome cockpit in Seated mode by default, with Standing mode available.

#### Scenario: Unsupported browser
- **WHEN** the browser lacks WebXR
- **THEN** no VR control is shown, and the flat-screen game is unaffected

### Requirement: Player scale is constant
During size transitions in XR, the player's world scale and horizon SHALL remain constant, and only the cockpit geometry SHALL change.

#### Scenario: Shrink in VR
- **WHEN** the player pulls the size lever from Villa to Seat
- **THEN** the interior folds in around the player over the transition time, the head height is unchanged, and the player feels one haptic pulse

### Requirement: Controller and hand mapping
XR controller and hand-tracking input SHALL map to the same named actions as other devices (§10), through quantized poses and diegetic console interactions (throttle orb, size lever, console buttons, wrist menu).

#### Scenario: Grab the lever by hand
- **WHEN** a tracked hand pinches the size lever and moves it one detent toward "smaller"
- **THEN** a Shrink action is emitted in that tick's command frame

### Requirement: Comfort options
XR SHALL provide a vignette (on by default), snap or smooth turning, teleport or smooth on-foot locomotion, a seated height offset, and reduced flashing, and SHALL never apply camera shake or roll.

#### Scenario: Hull hit in VR
- **WHEN** debris strikes the hull during an XR session
- **THEN** controllers get a haptic pulse, and the camera doesn't shake
