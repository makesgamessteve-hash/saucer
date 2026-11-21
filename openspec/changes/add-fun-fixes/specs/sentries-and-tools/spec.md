## MODIFIED Requirements

### Requirement: Watcher
A Watcher SHALL detect targets only within its sensor cone and its civ's size band, except that a hull below its band (the Seat) SHALL be seen within a short range (40 m by default), and when Locked it SHALL fire stun bolts that reduce shields, then hull, or Suit Charge on foot. A bolt SHALL hit a saucer only inside an ellipsoid of the hull's diameter and height scaled by a hurt scale (0.8 by default).

#### Scenario: Shrink below the band
- **WHEN** the saucer shrinks to Seat inside the cone of a Watcher whose band is M–XL, farther than 40 m from it
- **THEN** the Watcher returns to Dormant within 2 s

#### Scenario: A Seat up close
- **WHEN** a Seat flies 10 m in front of a Watcher whose band is M–XL
- **THEN** the Watcher sees it

#### Scenario: Rim corner
- **WHEN** a bolt passes the corner of the box around a saucer's rim
- **THEN** it does not hit

### Requirement: Seat hint
The first time a Watcher locks on to a player's Villa, the player SHALL get a tip that Watchers only see the Seat up close and how to fold down. Entering a site with Watchers in the Villa SHALL say how many Watchers lock on to a Villa there and that the Seat slips past them beyond 40 m.

#### Scenario: First lock
- **WHEN** a Watcher locks on to a Villa for the first time
- **THEN** a "TIP: Watchers only see a Seat up close" message appears once and never again

## ADDED Requirements

### Requirement: Light sentry at the tutorial site
The tutorial derelict (site 1 of the home sector) SHALL keep exactly one light Watcher in its biggest room that is not the entrance, preferring a room that is not the vault. A light Watcher SHALL see less far (55 m, a Seat within 25 m), lock after 1.5 s, and fire bolts of 4 damage.

#### Scenario: First threat early
- **WHEN** a new game starts
- **THEN** site 1 has one Watcher, marked light, and a Villa in its cone is shot at with 4-damage bolts

### Requirement: Scanner finds
The Scanner SHALL also report how many finds are left at the scanned site and the value and room of the best one.

#### Scenario: Scan a site
- **WHEN** the player scans a derelict with finds left
- **THEN** a message names the number of finds left, the best one's value and its room

### Requirement: Tool tips
A player SHALL get one tip naming the Decoy and the Shroud the first time a Watcher locks on after the Seat hint, and one naming the Jammer the first time a Snatcher locks on.

#### Scenario: First Snatcher lock
- **WHEN** a Snatcher locks on to the player for the first time
- **THEN** a tip names the Jammer, once

### Requirement: Denied feedback
A press of a tool button (jam, decoy, shroud, spike, scan, grapple, land, home, assist, fold and size keys) that changes nothing SHALL play the "denied" sound, and at most once per 10 s per button SHALL say where the tool works.

#### Scenario: A dead press
- **WHEN** the player presses Grapple while walking the dome
- **THEN** the "denied" sound plays and a message says the grapple works on foot only; a second press within 10 s plays the sound without the message
