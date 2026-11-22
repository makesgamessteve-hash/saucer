## ADDED Requirements

### Requirement: Loot condition
Every rolled find SHALL carry a condition that scales its value between 0.6x and 1.8x (skewed low), drawn last from the item's own seed so the rest of the roll and the determinism of items are unchanged.

#### Scenario: Values vary
- **WHEN** 300 finds of the same size and tier are rolled
- **THEN** the most valuable is worth more than three times the least
