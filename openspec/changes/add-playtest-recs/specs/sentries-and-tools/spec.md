## ADDED Requirements

### Requirement: Seat hint
The first time a Watcher locks on to a player's Villa, the player SHALL get a tip that Watchers ignore the Seat and how to fold down. Entering a site with Watchers in the Villa SHALL say how many Watchers lock on to a Villa there and that the Seat slips past them.

#### Scenario: First lock
- **WHEN** a Watcher locks on to a Villa for the first time
- **THEN** a "TIP: Watchers ignore anything as small as the Seat" message appears once and never again
