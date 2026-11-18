## ADDED Requirements

### Requirement: The Warden stays awake
Shutting a derelict's grid down SHALL power down every sentry except the Warden. While the grid is down the Warden SHALL keep patrolling and hunting at half speed, fire half as often and wake no Snatchers. Only the Jammer SHALL stun it and an Override spike shut it down. The grid console SHALL say that the Warden keeps patrolling.

#### Scenario: Grid down at danger 3
- **WHEN** a player shuts the grid of a site with a Warden
- **THEN** the other sentries power down and the Warden goes on patrolling, slower
