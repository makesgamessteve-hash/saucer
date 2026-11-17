## ADDED Requirements

### Requirement: Pocket configuration
The saucer SHALL have a third configuration, Pocket, about the size of a big coin (5 cm across). Pocket SHALL only be selectable while docked at a station; elsewhere the request SHALL be refused with a reason. Choosing it SHALL spend Charge, put the player on foot in the station's arrival hangar and fold the saucer down into the player's hand with an animation, after which it goes into the pocket.

#### Scenario: Pocket away from a station
- **WHEN** the player is in open space, not docked, and presses Pocket (3)
- **THEN** the request is refused with "Pocket only works docked at a station" and the configuration does not change

#### Scenario: Pocket while docked
- **WHEN** the player is docked at the trader in the Villa and presses Pocket
- **THEN** Charge is spent, the player stands in the arrival hangar, the saucer folds into the hand over a few seconds and is then slipped into the pocket

### Requirement: Unpocket in a hangar
Unpocketing SHALL only work in a hangar (or open space) whose space door is not blocked. It SHALL grow the saucer from the hand onto the hangar's pad with an animation and SHALL then put the player at the helm with the saucer at that hangar's bay outside the station.

#### Scenario: Unpocket outside a hangar
- **WHEN** the player is on the concourse with the saucer pocketed and presses Villa (1)
- **THEN** unpocketing is refused with a message to find a hangar

#### Scenario: Unpocket in the far hangar
- **WHEN** the player stands in the far hangar with the saucer pocketed and presses Villa (1)
- **THEN** the saucer grows from the hand onto the pad, and when it has grown the player is at the helm of the Villa at the far hangar's bay, still docked, and can fly away

### Requirement: Walkable station interiors
Each trader station SHALL have a walkable interior generated deterministically from its seed and the station kit: two hangars (arrival and far), a concourse spine with passages, a market with four or five stalls and a bar. Every stall and the bar counter SHALL be reachable along a navigation graph whose links are clear of walls and solids.

#### Scenario: Same station every visit
- **WHEN** the station layout is generated twice for the same seed
- **THEN** both layouts have the same hash, and layouts for other seeds differ

#### Scenario: Everything reachable
- **WHEN** a layout is generated for any seed
- **THEN** it has two hangars, a market, a bar and corridors, every navigation link is walkable and every node is reachable from the arrival hangar

### Requirement: Station folk and furnishing
Station interiors SHALL be furnished in the detail-pass style (wall panels, trims, pipes, lights, props) and SHALL be peopled with NPCs of several species: stall keepers, a bartender, patrons on stools and at tables, and strollers on the concourse.

#### Scenario: Folk at the bar
- **WHEN** the player walks into the bar
- **THEN** the bartender stands behind the counter and patrons sit at the stools and tables

### Requirement: On-foot movement on every input path
On foot in a station the player SHALL walk with collision in first person using the same walk and look axes as inside the saucer, on keyboard and mouse, gamepad, touch and WebXR (where the head direction steers walking). Sprint (boost), Use, holding the coin (F, tractor) and the size actions SHALL work on every input path; on gamepad, touch and WebXR, Pocket is reached by shrinking past the Seat and left with grow.

#### Scenario: Walk and collide
- **WHEN** the player walks on the concourse into a wall
- **THEN** the player stops at the wall and does not leave the station

#### Scenario: XR head steering
- **WHEN** a WebXR player looks behind and pushes the stick forward
- **THEN** the player walks the way the head faces

### Requirement: Trading with NPC traders on foot
Stall keepers SHALL buy and sell face to face: each vendor kind SHALL buy items at the trader's offer times its own multiplier (a bonus for the goods it deals in), sell its stock (ingredients, books and programs, modules), or offer services (Charge top-up and hull repair). The bar SHALL sell drinks that grant buffs and rumours that set leads. Talking to patrons and strollers SHALL show a line of chatter.

#### Scenario: Sell to the scrap dealer
- **WHEN** the player stands at the scrap dealer's stall, presses Use and picks an unidentified material
- **THEN** the item leaves the hold and the player is paid the trader's offer times 1.25

#### Scenario: A drink at the bar
- **WHEN** the player buys a nebula tea at the bar
- **THEN** credits are spent and the calm buff is active

### Requirement: The pickpocket and the chase
Each station SHALL have a hooded pickpocket who stalks a player with the saucer in the pocket. Looking straight at him SHALL spook him off for a cooldown, and a coin held in the hand SHALL be safe. If he reaches the player from behind he SHALL steal the saucer and flee along the navigation graph after a short head start. Catching him (Use in reach) SHALL return it. While stolen the saucer SHALL NOT unpocket.

#### Scenario: Stolen and caught
- **WHEN** the pickpocket steals the saucer and the player sprints after him and presses Use in reach
- **THEN** the saucer is back with the player and the catch is counted

### Requirement: The fence
If the pickpocket keeps away for the escape time, the saucer SHALL go to the fence at the bar, where it can be bought back for credits, traded for the best item in the hold or, broke and empty handed, pleaded for.

#### Scenario: Escaped to the fence
- **WHEN** the pickpocket keeps away for the escape time
- **THEN** the saucer is at the fence, and buying it back at the bar returns it

### Requirement: Station visits save and replay
The whole visit (body, coin state, pickpocket, bays) SHALL be plain data in the player state, saved and loaded like the rest of the sim, and SHALL be deterministic under replays and the restore-every-tick test mode; layouts SHALL be rebuilt from the seed and never saved.

#### Scenario: Save on foot
- **WHEN** the player saves in the market and loads the save
- **THEN** the player is on foot at the same spot with the saucer in the same place, in the same station layout
