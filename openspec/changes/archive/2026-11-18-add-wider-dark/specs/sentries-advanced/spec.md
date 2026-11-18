## ADDED Requirements

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
