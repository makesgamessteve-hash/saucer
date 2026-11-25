## MODIFIED Requirements

### Requirement: Light sentry at the tutorial site
The tutorial derelict (site 1 of the home sector) SHALL keep exactly one light Watcher in a big room on the way to the vault, preferring a hall to a shaft and never the entrance. A light Watcher SHALL see less far (70 m, a Seat within 18 m), fill its meter at 0.8 of the rate, lock after 1.2 s, and fire bolts of 6 damage.

#### Scenario: First threat early
- **WHEN** a new game starts
- **THEN** site 1 has one Watcher, marked light, and a Villa in its cone is shot at with 6-damage bolts

### Requirement: A hit shakes the beam loose
A bolt from any Watcher, a light one included, hitting the hull SHALL shake a beam pull in progress loose.

#### Scenario: Hit mid-pull
- **WHEN** a stun bolt hits the Villa while its beam pulls a find
- **THEN** the beam lets go and the find stays where it was

### Requirement: Site alarm
Each site SHALL keep an alarm level from 0 to 3 (2 at the tutorial derelict, which has no Snatchers or Lockdowns). Every Watcher lock and every Spotter tag SHALL raise it by one and say so on the HUD. At level 2 dormant Snatchers SHALL wake (sensing twice as far) and dormant Lockdown nodes SHALL trip. Locked Watchers SHALL fire sooner by 30 % of their interval per level (light Watchers by half that).

#### Scenario: Escalation
- **WHEN** two Watchers lock on the Villa at derelict 2
- **THEN** the HUD shows SITE ALARM 2/3, the Snatchers wake and the hall's Lockdown seals
