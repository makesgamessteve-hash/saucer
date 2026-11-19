## ADDED Requirements

### Requirement: Landing probe
The Villa SHALL be able to land on a surface from the helm with the Land button. A landing SHALL probe the ground under each of the three feet and the centre and SHALL be refused with a reason when a foot has no ground, when the feet's heights differ by more than the slope limit, when the hull would not fit, or when the saucer is reshaping, on the beam, clamped or too fast.

#### Scenario: Landing over a drop-off
- **WHEN** the player presses Land with one foot over the platform's edge
- **THEN** no landing starts and the message says there is no ground

#### Scenario: Landing on a slope
- **WHEN** the player presses Land with a step under part of the hull
- **THEN** no landing starts and the message says the ground is too steep

### Requirement: Gear and anchoring
A landing SHALL swing the three telescoping legs out and settle the hull down on them, and the landed saucer SHALL stay anchored to the surface until it lifts off. The Land button again SHALL lift off, or abort the descent.

#### Scenario: Landing on a flat platform
- **WHEN** the player presses Land over a flat platform
- **THEN** the legs swing out, the saucer settles at the gear height, and it stays put when the stick is pushed

### Requirement: Hull hatch rules
A landed Villa SHALL have a hull hatch aft of the engine room that slides open and unfolds stairs to the ground, so the player walks out and back in on foot. The hatch SHALL NOT open while the saucer flies, is reshaping or is on the beam. In vacuum or toxic air it SHALL open only after the player's suit has sealed. Taking off SHALL require the hatch to be closed.

#### Scenario: Leaving the Villa in open space
- **WHEN** the player uses the hatch panel on a landed Villa in vacuum
- **THEN** the helmet seals, the leaves slide apart, the stairs unfold to the ground, and the player walks down them and out

#### Scenario: Not while flying
- **WHEN** the player uses the hatch panel while the Villa flies
- **THEN** the hatch stays shut and the message says to land first

### Requirement: Hatch hysteresis
Like the interior doors the hull hatch SHALL decide with hysteresis and a minimum open time: it opens when the player is within reach, only starts to close once everyone is a margin farther, and never closes on a body in its way.

#### Scenario: Walking away
- **WHEN** the player walks away from the stairs
- **THEN** after the minimum open time the stairs fold and the hatch closes

### Requirement: Folding the Villa from outside
Outside a landed Villa the player SHALL be able to fold it into their hand and pocket it, at a Charge cost and only when its hatch is shut, and to unfold it again in front of them when there is room, where it lands on its gear. The Villa SHALL NOT fold into the pocket from aboard in a derelict.

#### Scenario: Pocket and unpocket
- **WHEN** the player folds the standing Villa and later unfolds it
- **THEN** it goes into the pocket, and unfolds ahead of the player standing on its gear with the stairs ready
