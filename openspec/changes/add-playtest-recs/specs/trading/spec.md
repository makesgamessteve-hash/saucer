## ADDED Requirements

### Requirement: Story item sale warning
At the trade terminal and at market stalls, the sell row of a story item (an undecoded data core, a holodeck module or program core) SHALL be marked, and the first pick SHALL only warn what the item is for. A second pick SHALL sell it.

#### Scenario: Data core at the scrap dealer
- **WHEN** a player picks "Sell Data core (undecoded)" at a stall
- **THEN** the core stays in the hold with a warning, and the next pick on "CONFIRM: sell" sells it
