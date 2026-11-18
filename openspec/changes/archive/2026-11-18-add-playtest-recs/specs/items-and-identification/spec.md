## ADDED Requirements

### Requirement: Decodes jump the queue
An Echo decode or a data core decode queued at the lab bench SHALL go ahead of every Identify job that is waiting or running; an Identify job pushed back SHALL keep its progress. With the second lab bench the first two jobs SHALL run at the same time.

#### Scenario: An Echo during a long Identify queue
- **WHEN** a player queues two Identify jobs and then an Echo decode
- **THEN** the Echo decode is first in the queue and finishes before either Identify job

#### Scenario: Two benches
- **WHEN** the second lab bench is fitted and two jobs are queued
- **THEN** both make progress every tick and the HUD lab line shows both
