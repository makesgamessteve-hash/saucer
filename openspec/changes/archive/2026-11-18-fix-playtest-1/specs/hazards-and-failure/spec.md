## ADDED Requirements

### Requirement: Hull mending
In open space, outside every site, the hull SHALL mend slowly once the saucer has gone the shield delay without a hit, and buffs that scale hull regen (Steady) SHALL speed it up. Inside a site the hull SHALL NOT mend. A hull at zero SHALL NOT mend (it folds back instead). After a Fold Retreat the player SHALL be told the hull mends slowly in open space and that the trade terminal repairs it at once.

#### Scenario: Steady mends the hull twice as fast
- **WHEN** two players at hull 50 wait ten seconds in open space and only one of them is Steady
- **THEN** both hulls have risen, and the Steady one has risen twice as much

#### Scenario: No mending in a derelict
- **WHEN** a damaged saucer hovers inside a site without being hit
- **THEN** its shields recharge but its hull stays where it is
