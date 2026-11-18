# sentries-advanced Specification

## Purpose
Advanced sentries and defences: the Clamp, lockdowns, decoys and the Shroud.

## Requirements

### Requirement: The Clamp
Derelicts in danger 2 and 3 sectors SHALL hold up to two Clamps in their great halls. A Clamp SHALL chase a saucer in sight within 30 m inside its leash and grip its hull: a clamped saucer cannot reconfigure and loses Charge until its pilot holds Boost for 2 s to shake it off or jams it. A shaken or jammed Clamp sinks to the floor, stunned.

#### Scenario: Shake it off
- **WHEN** a Clamp grips P1's Seat and P1 holds Boost for 2 s
- **THEN** the Clamp lets go and P1 can fold again

### Requirement: Lockdown
Danger 2 and 3 derelicts SHALL have a Lockdown node in the hall with the most big doors. When any Watcher in the site locks on, the node SHALL seal those doors for 60 s with solid barriers, then rest. Jamming the node SHALL open them.

#### Scenario: Sealed in
- **WHEN** a Watcher locks onto a saucer in a site with a Lockdown
- **THEN** the hall's big doors are sealed and the saucer cannot fly through them until the seal ends or the node is jammed

### Requirement: Decoys
Decoy (B, D-pad down, the touch Decoy button) SHALL throw one of three decoys ahead; for 8 s Watchers and Snatchers in sight within 80 m SHALL turn to it instead of the player.

#### Scenario: Throw
- **WHEN** a player inside a site throws a decoy past a Watcher
- **THEN** the Watcher turns to the decoy and the player has two left

### Requirement: The Shroud
Shroud (X, D-pad left) SHALL toggle a cloak that drains Charge; while it is up and the saucer hovers still, Watchers SHALL not see it and Clamps SHALL not chase it.

#### Scenario: Hidden while still
- **WHEN** a shrouded saucer hovers still in a Watcher's cone
- **THEN** the Watcher stays dormant

### Requirement: The Override spike
On foot, Spike (N, B button) next to a disabled sentry or a Lockdown node SHALL switch it off for good after 3 s and give the player its core, a sellable item. An overridden sentry SHALL stay off across saves and jumps.

#### Scenario: Override
- **WHEN** a player on foot spikes a jammed Clamp for 3 s
- **THEN** the Clamp is off, its core is in the player's hands, and it stays off after a save and load

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

### Requirement: The Warden stays awake
Shutting a derelict's grid down SHALL power down every sentry except the Warden. While the grid is down the Warden SHALL keep patrolling and hunting at half speed, fire half as often and wake no Snatchers. Only the Jammer SHALL stun it and an Override spike shut it down. The grid console SHALL say that the Warden keeps patrolling.

#### Scenario: Grid down at danger 3
- **WHEN** a player shuts the grid of a site with a Warden
- **THEN** the other sentries power down and the Warden goes on patrolling, slower
