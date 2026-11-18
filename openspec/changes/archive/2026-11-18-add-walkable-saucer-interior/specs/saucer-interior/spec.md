## ADDED Requirements

### Requirement: First-person avatar on foot
The player SHALL be a person with a body (radius 0.3 m, eye height 1.62 m) inside their own saucer, seen from their own eyes. The same move, turn and look actions SHALL walk the body on foot and fly the saucer at the helm, from keyboard/mouse, gamepad, touch and WebXR (where walking follows the head direction).

#### Scenario: Walk forward
- **WHEN** the player is on foot facing the helm and holds forward for one second
- **THEN** the body moves about 3.2 m toward the helm and the saucer does not move

#### Scenario: XR head direction
- **WHEN** an immersive XR session runs, the head looks to the saucer's right and the left stick is pushed forward
- **THEN** the body walks to the right

### Requirement: Walkable two-deck Villa
The Villa SHALL have a dome deck under a glass dome (an open-plan kitchen, living room and helm) and a lower deck reached by stairs (a bedroom, a bathroom and the engine room). Walls, furniture, rails and the hull edge SHALL block the body on both decks, and one Lua layout table SHALL drive both the collision and the code-generated interior meshes.

#### Scenario: Down the stairs
- **WHEN** the player walks from the dome deck into the high end of the stairs and on to the low end
- **THEN** they arrive on the lower-deck floor and the HUD names the room they are in

#### Scenario: Furniture blocks
- **WHEN** the player walks into the sofa or a partition wall
- **THEN** the body stops at its edge (sliding along it) and never passes through

### Requirement: Fly from the helm
Pressing Use within reach of the helm SHALL seat the player and give them control of the saucer with a seated first-person view. Pressing Use at the helm SHALL stand them up, and the saucer SHALL brake and hold station while nobody is at the helm.

#### Scenario: Take the helm and fly
- **WHEN** the player stands at the helm, presses Use and pushes forward
- **THEN** the saucer flies forward and the camera is the pilot's eyes

#### Scenario: Nothing to use
- **WHEN** the player presses Use in the bedroom
- **THEN** nothing changes and the HUD says "Nothing to use here"

### Requirement: Reconfigure around the player
A size change SHALL keep the player's eye point fixed: at the helm the pilot's eye, on foot wherever the player stands, facing where they look (they end up seated in the Seat). Rooms SHALL fold away before the hull shrinks and unfold after it grows, and the old and new hulls SHALL be drawn scaled about the eye point.

#### Scenario: Fold on foot
- **WHEN** the player stands in the living room and asks for the Seat
- **THEN** the Seat forms around their eye point, they are at its controls, and Charge drops by 20

### Requirement: Tractor through the glass
The tractor SHALL aim from the player's eyes, both seated at the helm and on foot at the dome, and SHALL obey the current size's tractor class and range.

#### Scenario: Grab from the dome
- **WHEN** the player stands at the dome wall looking at a cache inside the range
- **THEN** the cache can be tractored into the hold
