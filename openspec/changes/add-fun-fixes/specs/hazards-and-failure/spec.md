## MODIFIED Requirements

### Requirement: Fold Retreat
At zero hull, the saucer SHALL fold to the last visited trader. Half of its hot items, rounded up and the newest finds first, SHALL be lost for good; the rest SHALL drop as a recoverable cache at the point of failure. The player SHALL be told how many items were lost and how many stayed behind.

#### Scenario: Hull destroyed in a ruin
- **WHEN** hull reaches 0 holding 3 hot items and 2 banked items
- **THEN** the saucer appears at the trader with the 2 banked items, 2 hot items are lost for good, a 1-item cache sits in the ruin, and it's marked on the site map

#### Scenario: One hot item
- **WHEN** hull reaches 0 holding a single hot item
- **THEN** the item is lost for good and no cache is left

### Requirement: Tow bill
A Fold Retreat SHALL cost a tow bill by sector danger (40 c, 80 c and 140 c by default), multiplied by 2, 3 or at most 4 for each retreat that follows the last one within 10 minutes. It SHALL be paid from credits first; in a danger-2 or danger-3 sector what the player cannot pay SHALL come out of the Charge, never below zero, and at danger 1 the unpaid part SHALL be waived so the Charge stays. Nothing else SHALL be taken. The player SHALL be told what was paid.

#### Scenario: Broke at danger 2
- **WHEN** a player with 20 c and 100 Charge folds back in a danger-2 sector
- **THEN** they pay 20 c and 60 Charge and keep their banked cargo and Echoes

#### Scenario: Broke at home
- **WHEN** a player with 10 c and 50 Charge folds back in a danger-1 sector
- **THEN** they pay 10 c and keep all 50 Charge

#### Scenario: Tows close together
- **WHEN** a player folds back three times within ten minutes in a danger-1 sector
- **THEN** the bills are 40 c, 80 c and 120 c
