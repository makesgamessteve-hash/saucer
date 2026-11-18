## ADDED Requirements

### Requirement: Reconfiguration timing (v0.5)
Shrinking from the Villa SHALL take 1.5 s and growing to it 1.8 s, as data in `saucer/configs.lua`, so that the room packing can be read. Flight input SHALL be ignored during these transitions.

#### Scenario: Fold duration
- **WHEN** the Villa folds to the Seat
- **THEN** the reconfiguration ends after 90 ticks at 60 Hz
