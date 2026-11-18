# xenoarchive Specification

## Purpose
Identified finds are filed in the player's Xenoarchive, which pays rewards at 25%, 50% and 100%.

## Requirements

### Requirement: Filing identified finds
Entering a derelict SHALL file its civilization in the player's Xenoarchive. Identifying an item at the lab bench SHALL file its type under its civilization when that type is in the civilization's catalog (the item types of its domains). The percentage SHALL be the share of the catalog filed; the party's best percentage SHALL count for the translation gate.

#### Scenario: A first find
- **WHEN** a player identifies a curio of a civilization whose catalog has eight types
- **THEN** that civilization's archive shows 13%

### Requirement: Archive rewards
At 25% a civilization's lore book SHALL go on the bookshelf; at 50% its blueprint SHALL raise sale prices of its items by 15%; at 100% its signature piece SHALL be added to the hold.

#### Scenario: Blueprint
- **WHEN** a player reaches 50% for a civilization
- **THEN** its items sell for 15% more to that player
