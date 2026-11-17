## ADDED Requirements

### Requirement: The Warden
Each danger-3 derelict SHALL keep one Warden that patrols a route through its great halls joined by big doors and never leaves its halls. When it sees a hull (or a person on foot, closer) it SHALL hunt: chase within its halls keeping its distance and fire stun bolts.

#### Scenario: A Warden in the deep
- **WHEN** a party enters a danger-3 sector
- **THEN** a derelict there has one Warden patrolling its great halls

### Requirement: A hunting Warden raises the alarm
A hunting Warden SHALL sound the Lockdown alarm and wake every Snatcher of its site, which then sense twice as far for 30 s.

#### Scenario: Snatchers wake
- **WHEN** a Warden sees a hull
- **THEN** the site's Snatchers sense twice as far for 30 s

### Requirement: Stopping a Warden
A Decoy flare SHALL take a Warden's attention and the Shroud SHALL hide a still hull from it. Only the Jammer SHALL stun it, and an Override spike on a stunned Warden SHALL shut it down for good.

#### Scenario: Only the Jammer stops it
- **WHEN** a hunting Warden is jammed and spiked with the Override spike
- **THEN** it stays off for the rest of the visit

### Requirement: The grapple
On foot, the grapple (the Shroud key) SHALL fire a line up to 25 m toward the look direction and reel the body to where it hit, for 4% suit and at most 3 s.

#### Scenario: Grapple to a ledge
- **WHEN** a player on foot fires the grapple at a wall 20 m away
- **THEN** the body is reeled in to near that wall

### Requirement: The cutter
On foot, holding the spike key with no sentry to spike SHALL cut a sealed shutter or a Lockdown seal within 2.5 m in 6 s for 6% suit: a shutter slumps open for good, a seal opens the hall's doors. Letting go SHALL lose the progress.

#### Scenario: Cut a shutter
- **WHEN** a player holds the cutter on a sealed shutter for 6 s
- **THEN** the shutter is open for good
