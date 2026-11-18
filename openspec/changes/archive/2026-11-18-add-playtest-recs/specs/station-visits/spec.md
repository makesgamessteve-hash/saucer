## ADDED Requirements

### Requirement: Pickpocket chance
The pickpocket SHALL work a player's first station visit. After that each visit SHALL roll deterministically (universe seed, player, visit number) with a 25% chance; the two visits after a strike SHALL be quiet, and after six quiet visits he SHALL be sure to work the next. On a quiet visit he SHALL never stalk.

#### Scenario: Seven visits
- **WHEN** a player visits stations seven times
- **THEN** the pickpocket works the first visit, not the next two, and a minority of the rest
