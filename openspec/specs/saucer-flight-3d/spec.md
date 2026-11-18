# saucer-flight-3d Specification

## Purpose
Six-axis flight with a comfortable locked-interior bank, working on every input device with 3D helm readouts.

## Requirements

### Requirement: Six-axis flight
At the helm the saucer SHALL fly on six axes. Forward and back thrust SHALL follow the pilot's look yaw and pitch. Strafe SHALL be along the hull's right axis. Lift SHALL be along the hull's up axis at 0.8 times forward thrust. Turn SHALL change the yaw, and look SHALL change the pitch, limited to ±1.45 rad. Velocity SHALL ease toward the commanded vector. With no input the saucer SHALL brake to a hover that holds its altitude.

#### Scenario: Flying up and down
- **WHEN** the pilot holds lift up, then lets go, then holds lift down
- **THEN** the saucer climbs straight up, hovers at a constant altitude, and descends below where it started, without drifting sideways

#### Scenario: Fly where you look
- **WHEN** the pilot looks up and thrusts forward, then looks down and thrusts forward
- **THEN** the saucer climbs, then dives

### Requirement: Comfortable bank with a locked interior
The saucer SHALL lean into turns and strafes by at most BANK_MAX (0.18 rad), easing toward the stick, and SHALL level out when the stick is released. The hull, the interior and the pilot's eye SHALL bank together, so the inside of the saucer stays still relative to the pilot. The deck SHALL otherwise stay level. There SHALL be no bank in XR (the headset owns the horizon) or during a fold.

#### Scenario: Banking into a turn
- **WHEN** the pilot turns hard for two seconds and then lets go
- **THEN** the bank reaches but never exceeds BANK_MAX, and returns to level

### Requirement: Up and down on every input device
Every input device SHALL be able to command lift. On the keyboard that is Space and Ctrl, or R and Z. On a gamepad it is the triggers. Touch SHALL have the lift slider and two hold buttons, "up" and "dn", above and below it on the right edge. In WebXR it is the right stick's vertical axis. Touch lift SHALL be +1 or −1 while a button is held and 0 when it is released.

#### Scenario: Touch lift
- **WHEN** a finger holds the "up" touch button and then lifts off
- **THEN** the lift axis is +1 while it is held and 0 after release

### Requirement: 3D helm readouts
The helm radar SHALL float over the desk and show each contact on a stalk above or below the disc, by its height relative to the saucer, within 2400 m. The HUD SHALL show an altitude tape with vertical speed and pitch, and an "UP n m" or "DN n m" cue to the current target. The nearest site SHALL be the one with the nearest bounds.

#### Scenario: A contact below
- **WHEN** a site lies 160 m below the saucer
- **THEN** its radar blip hangs below the disc and the HUD reads "DN 160M"
