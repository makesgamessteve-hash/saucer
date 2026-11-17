## ADDED Requirements

### Requirement: Step out in a derelict
Inside a derelict, choosing the Pocket configuration (3, or shrinking past the Seat on any device) SHALL step the player out of the saucer when there is a deck within 2 m below the hull and room to stand (or crouch). It SHALL spend Charge, place the player on foot on that deck and fold the saucer into the player's hand, after which it goes into the pocket. Otherwise it SHALL be refused with a reason.

#### Scenario: Step out from the Seat
- **WHEN** the player hovers the Seat 1.3 m above a hall's deck at a crawlspace's mouth and presses 3
- **THEN** Charge is spent, the player stands on the deck with a full suit and empty hands, and the saucer folds into the hand and is then pocketed

#### Scenario: No deck
- **WHEN** the player presses 3 high above any floor
- **THEN** the request is refused with "No deck to stand on: set down within 2 m of a floor"

### Requirement: Deploy and board
On foot, Grow (or 1, 2) SHALL deploy the saucer, always as the Seat, only where a 2.2 m clearance sphere is free in front of the player or, failing that, around the player. The coin SHALL grow into the Seat with an animation; when it has grown the player SHALL be at the helm with the suit recharged and the hands emptied into the hold, any overflow staying as a cache.

#### Scenario: Deploy blocked
- **WHEN** the player is in a 1 m crawlspace and presses Grow
- **THEN** the deploy is refused with "No room to deploy" and a ghost of the Seat shows where it would not fit

#### Scenario: Deploy in the hall
- **WHEN** the player stands in a hall holding one find and presses Grow
- **THEN** the Seat grows from the coin, the player is aboard at the helm, and the find is in the hold

### Requirement: Movement on foot
On foot the player SHALL walk and run with the same input mapping as at a station, crouch while holding down, duck automatically into openings too low to stand in, stand up again when there is headroom, and jet-hop for Suit Charge, held to the deck by mag-boots. Movement SHALL collide with the derelict's walls, debris and shutters.

#### Scenario: Into a crawlspace
- **WHEN** the player walks into a crawlspace's 1 m mouth
- **THEN** the player crouches, crawls at crawl speed, and stands up again in the chamber behind it

### Requirement: Suit Charge
On foot the suit's Charge SHALL be the only meter. It SHALL drain over time, faster in crawlspaces and while a Watcher is Locked onto the player; jet-hops and the Jammer SHALL spend it; stun bolts SHALL bite it. There SHALL be no health. Warnings SHALL show at 30% and 10%. Boarding SHALL refill it.

#### Scenario: Warnings
- **WHEN** the Suit Charge drops through 30% and then 10%
- **THEN** a warning message appears at each, and the HUD shows the low and the critical warning

### Requirement: Four hand slots
On foot the player SHALL carry at most four items by hand, each at most carry size 2; Use SHALL take loot within reach. Delicate finds, which a beam would crush, SHALL only be taken by hand.

#### Scenario: Hands full
- **WHEN** the player holds four items and uses a fifth
- **THEN** the pick-up is refused with "Your hands are full (4): deploy the saucer to stow them"

### Requirement: Lifeline
The player's trail SHALL be recorded at points where the Seat would fit. At zero Suit Charge the screen SHALL white out, the Seat SHALL deploy at the newest valid trail point, the player SHALL wake at its helm with a full suit, and the items in the player's hands (other than Echoes and uniques) SHALL drop as a cache where the player fell, marked on the radar and recoverable by hand or beam.

#### Scenario: Suit runs out
- **WHEN** Suit Charge reaches 0 in the hall while holding a Delicate find
- **THEN** the player is at the helm of the Seat on their trail, a cache holding the find is where the player fell, and after stepping out again the player can take the cache back by hand

### Requirement: Crawlspaces, chambers and strongrooms
Every derelict SHALL have, off one great hall and generated deterministically from its seed on the ruin's own cell grid, a 1 m crawlspace that no saucer fits, a chamber behind it with standing room holding a hand-lock, a grid console and a Delicate find, and a strongroom with a Seat-sized door sealed by a shutter, holding a loot slot. The rest of the layout (rooms, doors, slots, layout hash) SHALL not change.

#### Scenario: Same features every visit
- **WHEN** a derelict is generated twice from the same seed
- **THEN** both have the same crawlspace route, chamber, strongroom and layout hash

### Requirement: Hand-locks open doors for the saucer
Holding Use at a hand-lock for its turn time SHALL open the shutter it is coupled to, which SHALL stop blocking the saucer, so the Seat can fly into the strongroom and beam up its loot. Moving or Use again SHALL let go. Opened locks SHALL stay open.

#### Scenario: Open the strongroom
- **WHEN** the player turns the chamber's hand-lock
- **THEN** the strongroom's shutter slides open, and the Seat flies through the door and beams up the strongroom's loot

### Requirement: Grid consoles
Holding Use at a grid console for its time SHALL shut down the derelict's sentry grid: every sentry of the site SHALL stay Disabled until the player who shut it leaves the site, then reboot.

#### Scenario: Grid down
- **WHEN** the player shuts down a derelict's grid with two sentries awake
- **THEN** both are Disabled and stay so while the player is in the site, and wake after the player leaves it

### Requirement: Sentries against a person on foot
A Watcher SHALL see a person on foot within its foot range whatever its size band; its stun bolt SHALL drain Suit Charge, never anything else. A Snatcher SHALL latch onto a person on foot carrying hot items and tear the last of them out of the hands. Nothing the player does to a sentry SHALL be lethal.

#### Scenario: Snatcher on foot
- **WHEN** a Snatcher latches onto a player on foot holding a hot item for its latch time
- **THEN** the item leaves the player's hands with "A Snatcher tore ... out of your hands"

### Requirement: Excursions save and replay
The excursion (body, coin, trail, work), Suit Charge, hands, turned hand-locks and shut grids SHALL be plain state: saved and loaded, snapshotted, restored every tick and replayed with the same hashes on every input path.

#### Scenario: Save on foot
- **WHEN** the game is saved on foot in a chamber with a turned hand-lock and one item in hand
- **THEN** loading it puts the player on foot in the same place with the same suit and hands, and the shutter still open

### Requirement: Excursion presentation on every device
On foot the view SHALL show the hand and the coin (or the body in the chase view), the saucer folding into and growing out of the hand, the derelict's shutters, hand-locks, consoles and Delicate finds, other players on foot, the HUD (suit bar and warnings, four hand slots, coin state, work progress, cache bearing, Lifeline white-out), the derelict audio loop, and in XR the wrist bars (suit, hands, work).

#### Scenario: XR wrist on foot
- **WHEN** a player in XR is on foot turning a hand-lock with a quarter of the suit left
- **THEN** the wrist shows a suit bar at 25% and a work bar filling, and no 2D text is drawn
