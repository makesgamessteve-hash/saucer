## ADDED Requirements

### Requirement: Price formula and demand
Sell price SHALL be `base × tier_mult × (1 + Σaffix_value) × civ_rarity × demand × sell_ratio`, with a sell ratio of 0.6 for identified items and 0.4 for unidentified. Each matching sale SHALL lower demand by 0.05 (floor 0.5), and demand SHALL recover by 0.01 per sim minute (cap 1.5).

#### Scenario: Saturation
- **WHEN** the player sells 4 identical Curios in a row
- **THEN** each successive offer is lower, and the 4th is priced at a demand 0.15 below the first (plus any recovery in between)

### Requirement: Buy and sell at a trader
Docking at a trader SHALL open a trade screen listing hold items with offers, and trader stock with prices. Transactions SHALL be atomic and saved immediately.

#### Scenario: Sell
- **WHEN** the player sells an item offered at ₵120
- **THEN** credits increase by 120, the item leaves the hold, and the save reflects both
