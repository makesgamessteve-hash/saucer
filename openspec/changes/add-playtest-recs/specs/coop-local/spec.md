## ADDED Requirements

### Requirement: Twin vaults
With two or more players, every derelict with two loot slots at least 30 m apart SHALL keep one twin vault and its shutter anchor, derived from the ruin. The vault SHALL be sealed to the beam until a partner beams the anchor and stays within 55 m of it in a saucer; then any other player SHALL be able to beam the vault up.

#### Scenario: One holds, one beams
- **WHEN** player 2 beams the shutter anchor and hovers near it while player 1 beams the twin vault
- **THEN** the vault comes up for player 1

#### Scenario: Sealed without a partner
- **WHEN** a player lines up the beam over the twin vault while nobody holds the anchor
- **THEN** the beam reports the shutter as shut and does not lock

### Requirement: Twin vault prizes
Taking a twin vault SHALL give both the beamer and the holder a prize two tiers above the vault's slot, into the hold or as a gift if it is full. A holder who drifts away SHALL let the shutter fall. The vault's state SHALL be per sector and survive saves and fold jumps.

#### Scenario: A prize each
- **WHEN** player 1 beams up the twin vault that player 2 holds open
- **THEN** both players get a prize and the vault is gone for both

### Requirement: Party requests
With two or more players each trader SHALL post a party request for three items of a category. One player SHALL bring at most two of them; when it is filled every player SHALL be paid and gain reputation with that trader, and a new one SHALL be posted.

#### Scenario: Shared request
- **WHEN** player 1 brings two matching items and player 2 brings the third
- **THEN** both players are paid and gain reputation
