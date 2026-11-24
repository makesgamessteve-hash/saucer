# saucer-upgrades Specification

## Purpose
Traders and station chandlers sell saucer upgrades (beam relay, tractor coils, hold racks, shield cells, a second lab bench).

## Requirements

### Requirement: Saucer upgrades
Trade terminals and station chandlers SHALL sell saucer upgrades with one price per level, kept per player. The helm beam relay SHALL be on sale from the start; tractor coils, hold racks, shield cells and the second lab bench SHALL need Fold Core tier 2. A fitted top level SHALL read "fitted" and not be for sale.

#### Scenario: Upgrades after Fold Core T2
- **WHEN** a docked player with Fold Core tier 1 and enough credits opens the trade terminal
- **THEN** the helm beam relay can be bought and the other upgrades show their price and "needs Fold Core T2"

### Requirement: Upgrade effects
Tractor coils SHALL shorten every beam pull, hold racks SHALL add hold slots everywhere the hold size is checked, shield cells SHALL make each shield point absorb more damage, and the second bench SHALL let the lab run two jobs at once.

#### Scenario: Hold racks
- **WHEN** a tier-2 player fits one level of hold racks
- **THEN** the hold takes 16 items instead of 12 and the HUD shows the new size

### Requirement: Beam relay from the start
A new pilot SHALL start with the helm beam relay fitted (level 1), so small finds can be tractored from the helm from the first dive; the shop SHALL show it as fitted. A record without it SHALL still be able to buy it.

#### Scenario: New game
- **WHEN** a new game starts
- **THEN** the player's beam relay level is 1 and buying it again answers "max"
