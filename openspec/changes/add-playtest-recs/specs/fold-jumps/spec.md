## ADDED Requirements

### Requirement: Fold warning
Picking a sector on the map whose danger is 2 or more and deeper than any the player has braved SHALL open a fold warning instead of proposing the jump. It SHALL say what the danger means for a Villa and point at the Seat. "Fold anyway" SHALL propose the jump and remember the danger as braved; "Not yet" SHALL close it. Arriving in a sector SHALL count as braving its danger.

#### Scenario: A fresh player picks danger 2
- **WHEN** a new player picks a danger-2 sector
- **THEN** no jump is proposed and the warning points at the Seat

### Requirement: Fold warning preparations
The fold warning SHALL add a line for each missing preparation: no Seat dive yet, Fold Core tier 1, or fewer than 100 credits together with the tow bill there.

#### Scenario: Broke and new
- **WHEN** a player with no credits and no Seat dive picks a danger-2 sector
- **THEN** the warning names the missing Seat dive and the tow bill

### Requirement: Ready to fold
In co-op each player SHALL be able to say they are ready to fold from the party panel; the others SHALL see "Pn READY TO FOLD" on the HUD. While a jump is being voted on, every view SHALL show each player's readiness. The flag SHALL clear on arrival.

#### Scenario: The waiting player
- **WHEN** player 2 has nothing left to loot and says they are ready to fold
- **THEN** player 1's HUD shows that player 2 is ready to fold
