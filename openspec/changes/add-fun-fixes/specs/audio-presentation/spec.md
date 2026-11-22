## ADDED Requirements

### Requirement: Pitch variance
Each one-shot event sound SHALL play at a pitch varied by up to 8 % either way, from a view-side generator that the simulation never reads.

#### Scenario: Repeated hits
- **WHEN** five bolts hit in a row
- **THEN** the hit sounds play at different pitches within 0.92x-1.08x
