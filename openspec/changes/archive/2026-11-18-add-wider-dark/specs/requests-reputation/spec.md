## ADDED Requirements

### Requirement: Trader requests
Each trader SHALL post three requests (a category, a minimum tier and, often, a civilization), generated from the seed. A matching item in the hold SHALL be deliverable from the trade terminal for twice its sale price (at least 40 c); a filled request SHALL be replaced by the next one.

#### Scenario: Deliver
- **WHEN** a player docked at a trader delivers a matching relic
- **THEN** the player is paid double, reputation there rises by one and a new request appears

### Requirement: Reputation
Reputation SHALL be kept per trader and player and SHALL have the levels Stranger, Known, Trusted and Partner. Each level up to Partner SHALL add 5% to that trader's prices for the player and unlocks Fold Core tiers.

#### Scenario: Known
- **WHEN** a player has filled one request at a trader
- **THEN** the player is Known there and gets 5% more for sales
