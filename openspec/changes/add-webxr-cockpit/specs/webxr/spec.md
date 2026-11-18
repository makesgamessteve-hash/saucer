## ADDED Requirements

### Requirement: Enter XR from the web build
When `navigator.xr` supports `immersive-vr`, the web build SHALL offer an "Enter VR" control, and it SHALL start the session in the dome cockpit in Seated mode by default, with Standing mode available.

#### Scenario: Unsupported browser
- **WHEN** the browser lacks WebXR
- **THEN** no VR control is shown, and the flat-screen game is unaffected

#### Scenario: Enter VR in the chosen mode
- **WHEN** the player presses Enter VR after choosing seated or standing in the comfort settings
- **THEN** the session starts in that reference space (seated in `local`, standing in `local-floor`, falling back to `local` without a floor)

### Requirement: Player scale is constant
During size transitions in XR, the player's world scale and horizon SHALL remain constant, and only the cockpit geometry SHALL change.

#### Scenario: Same scale in every cockpit
- **WHEN** the cockpit is the Villa, the Seat or any other pose
- **THEN** the eye separation, the unit axes, the head height and the horizon of the XR view are identical (a physical-headset check stays manual)

#### Scenario: Shrink in VR
- **WHEN** the player pulls the size lever from Villa to Seat
- **THEN** the interior folds in around the player over the transition time, the head height is unchanged, and the player feels one haptic pulse

### Requirement: Controller and hand mapping
XR controller and hand-tracking input SHALL map to the same named actions as other devices (§10), through quantized poses and diegetic console interactions (throttle orb, size lever, console buttons, wrist menu).

#### Scenario: Pinch and fist are trigger and grip
- **WHEN** a tracked hand pinches (thumb and index tips together) or makes a fist
- **THEN** the same action fires as the left trigger or the right grip would, and releasing stops it

#### Scenario: Grab the lever by hand
- **WHEN** a tracked hand pinches the size lever and moves it one detent toward "smaller"
- **THEN** a Shrink action is emitted in that tick's command frame

### Requirement: Comfort options
XR SHALL provide a vignette (on by default), snap or smooth turning, teleport or smooth on-foot locomotion, a seated height offset, and reduced flashing, and SHALL never apply camera shake or roll.

#### Scenario: Comfort settings in and out of XR
- **WHEN** the player opens "Comfort settings" from the title card or the bed, flat or in a headset, and changes turning, snap angle, vignette or mode
- **THEN** the setting applies at once, is saved in the user directory and is restored at the next start, and the snap angle turns the player by exactly that angle in the command frame

#### Scenario: Hull hit in VR
- **WHEN** debris strikes the hull during an XR session
- **THEN** controllers get a haptic pulse, and the camera doesn't shake
