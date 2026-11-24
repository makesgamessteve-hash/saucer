# saucer-interior Specification

## Purpose
A first-person avatar walks the two-deck Villa, flies from the helm, and the interior reconfigures around the player.

## Requirements

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

### Requirement: Wake-up start
A new game SHALL start with every player in "wake" mode beside their bed on the lower deck, with a title panel offering "Get up" and "Load saved game". The panel SHALL be driven by the move stick (up and down) and Use on every input device, and no other action SHALL work while it is open.

#### Scenario: Getting up
- **WHEN** a new game starts and the player presses Use
- **THEN** the player stands in the bedroom on foot and is told where the helm is

### Requirement: Sliding doors
The bedroom and bathroom SHALL have doors that slide open while a player's body is on their deck within reach, and close otherwise. A door SHALL be solid while less than 75 % open and SHALL NOT turn solid under a body that overlaps it. A door SHALL decide with hysteresis and move toward its goal at a fixed speed, so a body near a door never makes it open and close repeatedly.

#### Scenario: Hysteresis
- **WHEN** a body stands or sways near a door
- **THEN** the door opens when the body comes within reach, only starts to close once every body is farther than the reach plus a close margin and a minimum open time has passed, and rests exactly on its goal

#### Scenario: Walking through the bedroom door
- **WHEN** the player walks up to the bedroom door, through it, and away
- **THEN** the bedroom door opens on approach, lets them through, and closes behind them

#### Scenario: Standing still beside an open door
- **WHEN** the player stands one meter from the open bedroom door for three seconds
- **THEN** the door stays exactly fully open and makes no sound

#### Scenario: Swaying on the trigger edge
- **WHEN** the player's body creeps back and forth across the door's reach for ten seconds
- **THEN** the door opens once and stays open, with no repeated direction reversals and no repeated collision changes

#### Scenario: Not solid under a body
- **WHEN** a closed door's box overlaps a body
- **THEN** the door is not among the solids until the body is out

### Requirement: Furniture Use
Use on foot within reach of a station SHALL run that station's action: the kitchen makes the player well fed (Charge regenerates 1.5× as fast for five sim minutes), the shower refreshes, the engine console reads out Charge, the lab bench and trade terminal respond as places, and the bed opens a panel to sleep or load. Sleeping SHALL refill Charge and save the game, and SHALL be refused inside a derelict site.

#### Scenario: Cooking a meal
- **WHEN** the player uses the kitchen
- **THEN** they are well fed and Charge regenerates faster until the meal wears off

#### Scenario: Sleeping saves
- **WHEN** the player picks "Sleep until morning" at the bed outside a site
- **THEN** Charge is full and the game is saved

### Requirement: Helm console that keeps the view
The helm SHALL be a low desk with a radar of nearby sites, the trader and future markers, plus two side screens with live Charge, hull, shield, hold slots (hot and banked) and the size ladder. No part of it SHALL rise above the pilot's sight line through the dome.

#### Scenario: Flying from the helm
- **WHEN** the player flies from the helm
- **THEN** the view ahead through the dome is unobstructed and the console shows live readouts

### Requirement: The fold packs the rooms away
While folding from the Villa, the room groups SHALL pack away one after another, farthest from the pilot first. Each SHALL flatten, then slide into fold-space at the pilot's feet. The hull SHALL keep its full size until the rooms are packed, then shrink about the pilot's eye. Unfolding SHALL grow the hull first and then unpack the decks and rooms nearest first.

#### Scenario: Staggered packing
- **WHEN** the player folds to the Seat while standing in the kitchen
- **THEN** some rooms are already packed while others are still out, the farthest room finishes first, and the eye does not move

### Requirement: Clear dome view
The glass dome's meridian struts SHALL be slim (0.05 m by 0.04 m) and none SHALL stand within 30 degrees of straight ahead of the helm, so the view out of the helm is clear.

#### Scenario: Looking out from the helm
- **WHEN** the player sits at the helm and looks ahead
- **THEN** no dome strut crosses the middle of the view

### Requirement: The saucer's own lights
The saucer SHALL carry three switchable lights: cabin lamps in each Villa room (on by default), two forward headlight spots in the rim that cast shadows, and a flood under the hull that lights all around. The saucer's own lights SHALL pass through its own hull. The HUD SHALL show which lights are on and the help SHALL list the keys.

#### Scenario: Cabin lamps off
- **WHEN** the player switches the cabin lamps off in the Villa
- **THEN** fewer lights light the frame and the rooms are lit only by what comes through the dome

#### Scenario: Headlights in a dark hall
- **WHEN** the player switches the headlights on inside a derelict
- **THEN** two spot lights of the saucer's own are active and one shadow map serves the pair
