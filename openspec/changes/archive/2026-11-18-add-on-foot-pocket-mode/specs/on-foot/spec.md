## ADDED Requirements

### Requirement: Pocket and deploy
From Seat, on a standable surface, the player SHALL be able to step out, which pockets the saucer. Deploying SHALL place the saucer at Seat size only if a 2.2 m clearance sphere is free.

#### Scenario: Pocket from Villa
- **WHEN** the saucer is Villa, landed on a standable surface, and the player presses Step Out
- **THEN** the saucer chains shrinks to Seat (spending Charge), the player is placed on foot, and the saucer is pocketed

#### Scenario: Deploy blocked
- **WHEN** the player is in a 1 m crawlspace and presses Recall
- **THEN** recall is refused with "No room to deploy"

### Requirement: Suit Charge and Lifeline
On foot, Suit Charge SHALL drain over time (faster in hazards). There SHALL be no health stat. At zero Suit Charge, the saucer SHALL auto-deploy at the nearest valid point along the player's recorded path, and the player's hand-held items SHALL drop as a recoverable cache.

#### Scenario: Suit runs out
- **WHEN** Suit Charge reaches 0 while holding 2 items
- **THEN** the player is placed in the Seat at the nearest valid deploy point, a cache with both items appears where the player fell, and the cache is marked on the site map
