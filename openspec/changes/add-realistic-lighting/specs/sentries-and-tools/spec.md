## ADDED Requirements

### Requirement: Lights give you away
Headlights and floods SHALL add to the saucer's stealth signature (tuning `stealth.lights`), so a Watcher reads a lit saucer sooner. A player on foot outside the saucer SHALL not carry its lights' signature.

#### Scenario: Floods on
- **WHEN** a player switches the floods on in front of a Watcher
- **THEN** the signature rises by the floods' tuning and the meter fills faster
