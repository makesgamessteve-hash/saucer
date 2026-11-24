# sentries-and-tools Specification

## Purpose
Sentries follow a state machine (Watcher, Snatcher) and the player answers with non-lethal tools.

## Requirements

### Requirement: Sentry state machine
Every sentry SHALL follow Dormant → Alert → Locked → Disabled → Dormant with distinct light and sound telegraphs for each state, and SHALL stay leashed inside its ruin's bounding volume.

#### Scenario: Telegraph before acting
- **WHEN** a Watcher first detects the player
- **THEN** it spends at least 0.75 s in Alert (yellow light, rising tone) before becoming Locked

### Requirement: Watcher
A Watcher SHALL detect targets only within its sensor cone and its civ's size band (the Seat only within 25 m by default) and SHALL keep a suspicion meter (0 to 1) that fills while it sees the player, scaled by signature, closeness and the site alarm, and drains out of sight. When Locked it SHALL fire stun bolts that reduce shields, then hull, or Suit Charge on foot, hitting a saucer only inside its hull ellipsoid scaled by a hurt scale (0.8 by default).

#### Scenario: Shrink below the band
- **WHEN** the saucer shrinks to Seat inside the cone of a Watcher whose band is M–XL, farther than 25 m from it
- **THEN** the Watcher returns to Dormant within 2 s

#### Scenario: A glimpse slips away
- **WHEN** the Seat crosses a Watcher's sweep and leaves it while the meter is between half and full
- **THEN** the Watcher goes Alert, never Locks, and the meter drains back to zero out of sight

#### Scenario: The Villa is read fast
- **WHEN** the Villa hovers still in front of a Watcher 20 m away
- **THEN** the meter fills within about a second and the Watcher Locks after its Alert time

#### Scenario: A Seat up close
- **WHEN** a Seat flies 10 m in front of a Watcher whose band is M–XL
- **THEN** the Watcher sees it

#### Scenario: Rim corner
- **WHEN** a bolt passes the corner of the box around a saucer's rim
- **THEN** it does not hit

### Requirement: Snatcher
A Snatcher SHALL target only hot items. It SHALL latch onto a Seat hull (siphoning one hot item after 3 s) or onto the player on foot once excursions exist (taking one held item), then carry the item to its nest, where the player can recover it. It SHALL NOT be able to latch onto the Villa.

#### Scenario: Recover from the nest
- **WHEN** a Snatcher steals a hot item and reaches its nest
- **THEN** the item sits in the nest as a pickup, and picking it up restores it as a hot item

### Requirement: Non-lethal tools
The MVP SHALL provide a Scanner pulse (reveals sentry cones, paths, and nests for 10 s) and a Jammer (sends sentries in a 15 m cone to Disabled for 12 s), both with Charge costs and cooldowns defined in Lua data. Neither the tools nor the sentries SHALL destroy anything.

#### Scenario: Jam a latching Snatcher
- **WHEN** the player Jams a Snatcher 2 s into a latch
- **THEN** the latch is cancelled, no item is taken, and the Snatcher reboots for 12 s

### Requirement: Grid consoles
Ruins containing sentries SHALL include at least one grid console as an on-foot hand-lock that disables every sentry in its zone until the player leaves the site.

#### Scenario: Grid off
- **WHEN** the player uses a grid console on foot
- **THEN** every sentry in that zone enters Disabled and stays Disabled until the player leaves the site

### Requirement: The dome is out of reach
Sentries SHALL NOT target, affect, or path into the dome interior.

#### Scenario: Inside the dome near a Watcher
- **WHEN** the player walks the Villa dome while a Locked Watcher fires at the hull
- **THEN** the hull takes damage, and nothing affects the player or the dome's contents

### Requirement: Seat hint
The first time a Watcher locks on to a player's Villa, the player SHALL get a tip that Watchers only see the Seat up close and how to fold down. Entering a site with Watchers in the Villa SHALL say how many Watchers lock on to a Villa there and that the Seat slips past them beyond 25 m.

#### Scenario: First lock
- **WHEN** a Watcher locks on to a Villa for the first time
- **THEN** a "TIP: Watchers only see a Seat up close" message appears once and never again

### Requirement: Light sentry at the tutorial site
The tutorial derelict (site 1 of the home sector) SHALL keep exactly one light Watcher in a big room on the way to the vault, preferring a hall to a shaft and never the entrance. A light Watcher SHALL see less far (55 m, a Seat within 15 m), lock after 1.5 s, and fire bolts of 4 damage.

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

### Requirement: Lights give you away
Headlights and floods SHALL add to the saucer's stealth signature (tuning `stealth.lights`), so a Watcher reads a lit saucer sooner. A player on foot outside the saucer SHALL not carry its lights' signature.

#### Scenario: Floods on
- **WHEN** a player switches the floods on in front of a Watcher
- **THEN** the signature rises by the floods' tuning and the meter fills faster

### Requirement: Suspicion thresholds
A Watcher SHALL turn Alert at a half-full meter and SHALL turn Locked only at a full meter after at least its Alert time. After a lost lock the meter SHALL drop to a remembered 0.45, below Alert.

#### Scenario: Lock lost
- **WHEN** the Seat ducks out of a Watcher that had it Locked
- **THEN** the Watcher returns to Dormant with its meter at 0.45 or less

### Requirement: A hit shakes the beam loose
A bolt from a non-light Watcher hitting the hull SHALL shake a beam pull in progress loose.

#### Scenario: Hit mid-pull
- **WHEN** a stun bolt hits the Villa while its beam pulls a find
- **THEN** the beam lets go and the find stays where it was

### Requirement: Site alarm
Each site SHALL keep an alarm level from 0 to 3 (1 at the tutorial derelict). Every Watcher lock and every Spotter tag SHALL raise it by one and say so on the HUD. At level 2 dormant Snatchers SHALL wake (sensing twice as far) and dormant Lockdown nodes SHALL trip. Locked Watchers SHALL fire sooner by 30 % of their interval per level (light Watchers never).

#### Scenario: Escalation
- **WHEN** two Watchers lock on the Villa at derelict 2
- **THEN** the HUD shows SITE ALARM 2/3, the Snatchers wake and the hall's Lockdown seals

### Requirement: Site alarm cooldown
The alarm SHALL fall a level per 30 s while no player is at the site, or per 90 s inside, as long as no sentry there is Alert, Locked, hunting or latched.

#### Scenario: Cooldown
- **WHEN** the player leaves a site at alarm 2
- **THEN** the alarm reads 1 after 30 s and 0 after 60 s

### Requirement: Readable sweeps and cover
Each Watcher turret SHALL sweep in one of three patterns (smooth, stepped with holds, holding at the ends) with its own period, chosen from the site seed; a light Watcher SHALL always sweep smoothly. Its cone SHALL show as a light pool on the floor. Hall Watchers SHALL sit off-centre, and their rooms SHALL get pillars on side walls without doors, kept clear of floor hatches, that block sight.

#### Scenario: Learn the rhythm
- **WHEN** a player watches a stepped turret for two periods
- **THEN** it holds still at six stops in a fixed order and its floor pool shows where it looks

### Requirement: Guarded finds
Each hall Watcher's room SHALL hold one guarded find on the floor inside its sweep cone, worth 1.6x a plain find of its tier, sized for the Seat. The Scanner SHALL count the guarded finds and mark them. A guarded find SHALL drop back out of the beam while its guard is Alert or Locked on the player.

#### Scenario: Beamed under the guard's eye
- **WHEN** the player pulls a guarded find and its Watcher turns Alert on them
- **THEN** the beam lets go with "The guard saw the beam" and the find stays on the floor

### Requirement: Power-cell sabotage
Each hall Watcher SHALL carry a power cell on the floor behind it, out of its cone wherever it sweeps. Pulling it with the beam SHALL take at least 3 s; the Override spike on foot SHALL take it too. Taking it SHALL shut that Watcher off for good and put a sellable "Watcher power cell" (45 c) in the hold. If a Watcher sees the player while they pull a cell, it SHALL lock at once, raise the alarm and the beam SHALL let go.

#### Scenario: Sabotage
- **WHEN** the Seat pulls a hall Watcher's cell unseen
- **THEN** the Watcher goes dark for good, the cell is in the hold and the Scanner no longer lists it

#### Scenario: Caught at the cell
- **WHEN** the Watcher's sweep finds the player mid-pull
- **THEN** it locks at once, the alarm rises and the pull fails

### Requirement: Spotter drone
Sites with at least two non-light Watchers, and the tutorial derelict (light), SHALL have a Spotter drone that patrols the Warden route, never fires and keeps its own suspicion meter (45 m range, 20 m below the band or on foot). When its meter fills it SHALL tag the player: every Watcher at the site SHALL jump to a meter of at least 0.9, the alarm SHALL rise, and the Spotter SHALL rest 8 s. A Decoy SHALL draw it off and the Jammer SHALL stun it like any sentry.

#### Scenario: Tagged
- **WHEN** a Spotter's meter fills on the Villa
- **THEN** the HUD shows TAGGED, every Watcher there is at least Alert-ready and the alarm rises by one

### Requirement: Suspicion on the HUD
At the helm and on foot the HUD SHALL show an arc of 15 dots filled by the highest suspicion meter on the player, labelled SEEN or SPOTTER with the percentage, and an alert line for the site alarm and for a Spotter tag. The Scanner SHALL also draw Watcher cones, cells, guarded finds and the Spotter's cone, and report the alarm level.

#### Scenario: Read the danger
- **WHEN** a Watcher's meter on the player is at 60 %
- **THEN** 9 of 15 arc dots are lit and the label reads SEEN 60%

### Requirement: Stealth playtest persona
The fun-audit harness SHALL include a Stealth persona: the Human-Proxy career with a 200 ms delay, plus scan on entering a site, Decoy on Alert or a rising Spotter, Jam on Lock, lying low while suspected and pulling Watcher cells before a room's finds.

#### Scenario: Audit run
- **WHEN** `tools/funaudit/run.sh stealth 3 72000 OUT` runs
- **THEN** the log carries FUNE events for scans, decoys, sabotage and tags
