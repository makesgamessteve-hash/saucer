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

### Requirement: Station tractor dock
Every trader station SHALL carry a hangar bay with a dock pad, walls, a force field across its front and a door in its back wall that leads into the station. A Villa that approaches the bay slowly, in front of it, SHALL be taken over by the station's tractor beam and towed in along a smooth curve onto the pad, where the pad's clamps close on its feet.

#### Scenario: Approaching the bay
- **WHEN** the Villa slows down within the capture radius in front of a station's bay
- **THEN** the tractor beam takes over, tows it onto the dock pad, and the clamps close

### Requirement: Cancelling and leaving the dock
The player SHALL be able to cancel the tow by pulling away or with the Land button, and the beam SHALL NOT grab the saucer again until it has left the beam's reach. The Land button near the bay SHALL ask for a tow. At lift-off the clamps SHALL open before the saucer rises, and the beam SHALL carry it out of the bay before the helm is the player's again.

#### Scenario: Pulling away
- **WHEN** the player thrusts away from the bay for a moment during the tow
- **THEN** the beam lets go and does not grab again until the saucer is clear of its reach

### Requirement: Walking the dock
The bay SHALL hold breathable air, so leaving the Villa there needs no helmet or airlock cycle. The bay door SHALL lead into the walkable station and back, with the Villa staying docked. The player SHALL be able to fold the Villa into the pocket in the bay and unfold it again where there is clear space; with none the Villa SHALL NOT unfold and the player SHALL be told so. The Villa SHALL NOT pocket from aboard at a station.

#### Scenario: Through the bay door
- **WHEN** the player walks down the stairs, across the bay and through its back door
- **THEN** they are on the station's concourse, the Villa is docked and clamped, and walking back through the door returns them to the bay

### Requirement: Landing readout
At the helm the HUD SHALL show the distance to the ground under the gear, the slope under the three feet and whether the Villa can land there, with the reason when it cannot, and the feet's landing spots SHALL be marked on the ground green or red.

#### Scenario: Looking for a place to land
- **WHEN** the Villa hovers within 90 m of a step that makes the ground too steep
- **THEN** the HUD shows the ground distance, the slope and the reason, and the markers are red

### Requirement: Landing anywhere
The Villa SHALL land on any level solid surface: a derelict's hull, a plaza, a rooftop landing pad, a moon, a planet or an asteroid. The touchdown message SHALL say what it stands on and the suit SHALL use that place's air and pull. If the ground under a landed Villa that someone is flying disappears, the gear SHALL retract and the thrusters SHALL take over.

#### Scenario: Landing on a moon city's rooftop pad
- **WHEN** the player lands on a rooftop landing pad of a moon city
- **THEN** the message names a moon city rooftop, and leaving the Villa there needs the helmet because the air is vacuum

### Requirement: The EVA kit
Outside a Villa the player SHALL wear a helmet that goes on by itself in vacuum or toxic air, shown as a faint rim, and a HUD with oxygen, suit integrity, jetpack fuel, the distance and direction to the Villa, gravity, temperature, radiation, carried loot and the teleport's state. Oxygen SHALL drain only in air that is not breathable, and refill with fuel beside the standing Villa. Radiation, cold and hard landings SHALL wear down the suit.

#### Scenario: Out of breath
- **WHEN** oxygen falls to 30% and then 15% away from the Villa
- **THEN** the player is warned, then the return assist flies them home, and at zero the suit teleports them to the Villa

### Requirement: The jetpack and return assist
In zero gravity the jetpack SHALL fly in all six directions along the view, with inertia and automatic braking when no thrust is asked for. In a pull, thrusting up SHALL boost, a neutral stick SHALL hover and thrusting down SHALL descend, all burning fuel. The return assist SHALL fly the player to the Villa's stairs until they take the controls, the fuel runs out or the way is blocked.

#### Scenario: Letting go
- **WHEN** the player stops thrusting in zero gravity
- **THEN** they brake to a stop and hang in place

### Requirement: The emergency teleport
A button SHALL start a short charge-up that a second press cancels, after which the player SHALL be at the Villa's stairs, with the Villa redeployed where it stood if it was in the pocket. It SHALL cost half of what the player carries, left behind as a cache, and start a long cooldown. Running out of oxygen or suit integrity SHALL fire it without charge-up or cooldown check. It SHALL never be lethal.

#### Scenario: Teleporting from the cooldown
- **WHEN** the player presses the button during the cooldown
- **THEN** nothing is teleported and the seconds left are shown
