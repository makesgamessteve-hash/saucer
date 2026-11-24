# hazards-and-failure Specification

## Purpose
Hazards hurt the saucer, never kill the player, and failure costs items and time rather than the run.

## Requirements

### Requirement: The dome is safe
Damage volumes and hostile entities SHALL NOT affect the player while they're inside the dome interior, regardless of what's happening to the hull.

#### Scenario: Hull hit while walking the dome
- **WHEN** debris strikes the Villa hull while the player is at the lab bench
- **THEN** hull integrity drops, an alarm plays, and the player's Suit Charge and held items are unaffected

### Requirement: Hot and banked items
Items picked up at a site SHALL be *hot*, tracked per player, until that player leaves that site's boundary (its bounding volume plus 200 m), at which point they SHALL become *banked*. Banked items, installed modules, credits, and the dome SHALL NOT be lost through any failure on Standard or Cozy difficulty.

#### Scenario: Banking
- **WHEN** the player leaves a ruin's boundary carrying 2 hot items
- **THEN** both items are marked banked and are no longer eligible for loss

### Requirement: Fold Retreat
At zero hull, the saucer SHALL fold to the last visited trader. Half of its hot items, rounded up and the newest finds first, SHALL be lost for good; the rest SHALL drop as a recoverable cache at the point of failure. The player SHALL be told how many items were lost and how many stayed behind.

#### Scenario: Hull destroyed in a ruin
- **WHEN** hull reaches 0 holding 3 hot items and 2 banked items
- **THEN** the saucer appears at the trader with the 2 banked items, 2 hot items are lost for good, a 1-item cache sits in the ruin, and it's marked on the site map

#### Scenario: One hot item
- **WHEN** hull reaches 0 holding a single hot item
- **THEN** the item is lost for good and no cache is left

### Requirement: Non-lethal damage
No hazard or sentry SHALL reduce anything other than shields, hull, or Suit Charge, and none SHALL end the save on Cozy or Standard difficulty.

#### Scenario: Repeated failure
- **WHEN** the player triggers Fold Retreat 10 times in a row
- **THEN** the save remains playable, with all banked items intact

### Requirement: Hull mending
In open space, outside every site, the hull SHALL mend slowly once the saucer has gone the shield delay without a hit, and buffs that scale hull regen (Steady) SHALL speed it up. Inside a site the hull SHALL NOT mend. A hull at zero SHALL NOT mend (it folds back instead). After a Fold Retreat the player SHALL be told the hull mends slowly in open space and that the trade terminal repairs it at once.

#### Scenario: Steady mends the hull twice as fast
- **WHEN** two players at hull 50 wait ten seconds in open space and only one of them is Steady
- **THEN** both hulls have risen, and the Steady one has risen twice as much

#### Scenario: No mending in a derelict
- **WHEN** a damaged saucer hovers inside a site without being hit
- **THEN** its shields recharge but its hull stays where it is

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
