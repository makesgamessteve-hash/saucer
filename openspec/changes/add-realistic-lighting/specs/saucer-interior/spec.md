## ADDED Requirements

### Requirement: The saucer's own lights
The saucer SHALL carry three switchable lights: cabin lamps in each Villa room (on by default), two forward headlight spots in the rim that cast shadows, and a flood under the hull that lights all around. The saucer's own lights SHALL pass through its own hull. The HUD SHALL show which lights are on and the help SHALL list the keys.

#### Scenario: Cabin lamps off
- **WHEN** the player switches the cabin lamps off in the Villa
- **THEN** fewer lights light the frame and the rooms are lit only by what comes through the dome

#### Scenario: Headlights in a dark hall
- **WHEN** the player switches the headlights on inside a derelict
- **THEN** two spot lights of the saucer's own are active and one shadow map serves the pair
