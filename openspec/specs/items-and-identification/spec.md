# items-and-identification Specification

## Purpose
Items are deterministic, unidentified until the lab bench identifies them, and decodes jump the lab queue.

## Requirements

### Requirement: Deterministic items
An item's base type, tier, origin civ, affixes, and quirks SHALL be derived from `(site_seed, slot_index)`.

#### Scenario: Reload consistency
- **WHEN** a player saves before looting slot 7, reloads, and loots it
- **THEN** the item is identical to the one rolled before the reload

### Requirement: Identification
Unidentified items SHALL hide their affixes and quirks. The lab bench SHALL identify an item in `30 s × tier` of sim time, and installing an unidentified module SHALL apply its quirks immediately.

#### Scenario: Hidden quirk
- **WHEN** an unidentified "Unstable" module is installed
- **THEN** the Charge drain applies at once, and the HUD shows "Unknown effect"

### Requirement: Echoes are not sellable
Echo items SHALL be marked non-sellable and non-installable, and SHALL never be lost through a failure.

#### Scenario: Trade screen
- **WHEN** the player opens a trade screen holding an Echo
- **THEN** the Echo is listed as "Not for sale"

### Requirement: Decodes jump the queue
An Echo decode or a data core decode queued at the lab bench SHALL go ahead of every Identify job that is waiting or running; an Identify job pushed back SHALL keep its progress. With the second lab bench the first two jobs SHALL run at the same time.

#### Scenario: An Echo during a long Identify queue
- **WHEN** a player queues two Identify jobs and then an Echo decode
- **THEN** the Echo decode is first in the queue and finishes before either Identify job

#### Scenario: Two benches
- **WHEN** the second lab bench is fitted and two jobs are queued
- **THEN** both make progress every tick and the HUD lab line shows both

### Requirement: Loot condition
Every rolled find SHALL carry a condition that scales its value between 0.6x and 1.8x (skewed low), drawn last from the item's own seed so the rest of the roll and the determinism of items are unchanged.

#### Scenario: Values vary
- **WHEN** 300 finds of the same size and tier are rolled
- **THEN** the most valuable is worth more than three times the least
