## ADDED Requirements

### Requirement: Seeded sector contents
A sector SHALL be generated deterministically from its seed, with 8–16 sites, 1–2 traders, a danger tier, and site risk ratings visible after a scan.

#### Scenario: Same seed, same sector
- **WHEN** sector seed `0xBEEF` is generated twice
- **THEN** the site list, positions, archetypes, and risk ratings are identical
