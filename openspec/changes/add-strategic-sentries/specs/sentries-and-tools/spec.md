## MODIFIED Requirements

### Requirement: Watcher
A Watcher SHALL detect targets only within its sensor cone and its civ's size band (a hull below the band only up close), and SHALL keep a suspicion meter from 0 to 1 per Watcher. While it sees the player the meter SHALL fill at a rate scaled by the player's signature (hull size, speed, a working beam, Loud modules), by closeness and by the site alarm; out of sight it SHALL drain. The Watcher SHALL turn Alert at half and SHALL turn Locked only at a full meter after at least its Alert time. When Locked it SHALL fire stun bolts that reduce shields, then hull, or Suit Charge on foot. After a lost lock the meter SHALL drop to a remembered 0.45, below Alert.

#### Scenario: Shrink below the band
- **WHEN** the saucer shrinks to Seat inside the cone of a Watcher whose band is M–XL
- **THEN** the Watcher returns to Dormant within 2 s

#### Scenario: A glimpse slips away
- **WHEN** the Seat crosses a Watcher's sweep and leaves it while the meter is between half and full
- **THEN** the Watcher goes Alert, never Locks, and the meter drains back to zero out of sight

#### Scenario: The Villa is read fast
- **WHEN** the Villa hovers still in front of a Watcher 20 m away
- **THEN** the meter fills within about a second and the Watcher Locks after its Alert time

## ADDED Requirements

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
