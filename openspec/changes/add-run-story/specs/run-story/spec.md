## ADDED Requirements

### Requirement: Plot skeletons
A run SHALL have one story, chosen from the universe seed among a handful of plot skeletons (a civilisation vanished overnight, a war that ended both sides, a signal calling everyone home, the builders of the player's saucer, a sleep the Watchers guard), each of 4 to 6 beats whose last beat is a finale with one text per ending.

#### Scenario: a handful of plot skeletons each have four to six beats ending in a finale per ending
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the seed picks the skeleton: every skeleton and several twists turn up across seeds
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a skeleton limited to other causes is not picked
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: A story from the run's own parts
The story SHALL be filled from what the run generated: the civilisation, object and place of the central mystery, a second civilisation, what the Echo really is, who betrayed whom, and the trait words of the civilisations; the text SHALL come from templates and vocabulary only, as a pure function of the universe seed, so that co-op peers and later visits agree.

#### Scenario: is a pure function of the seed: same seed same story, other seeds differ
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: is filled from the run: the mystery's civilisation, object and place, a second civilisation, what the Echo is
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: leaves no template unfilled and no clue text empty, for any seed
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: an unknown template word stays visible instead of vanishing
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: there is no story without a mystery
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Twists
A run SHALL swap in at most one twist from a fixed list, such as "the Watchers were caretakers, not the enemy", which SHALL replace the text of the skeleton's reveal beat and add a line to every ending; a twist SHALL only be offered to the skeletons it fits.

#### Scenario: a twist replaces the reveal and adds a line to every ending, and only fits the skeletons it names
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the caretakers twist turns the Watchers into caretakers
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Beats bound to real places
Every beat SHALL be bound to a site that exists in the generated universe (a derelict of the home sector or a far sector on the mystery's spine, a body city's archive, or the Heart), the first clue in the tutorial derelict, and each clue's text SHALL end with a lead naming the place of the next beat.

#### Scenario: every beat is bound to a real site: its sector, kit and civilisation are the generated ones
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the first clue waits in the tutorial derelict and no two derelict clues share a site
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: each clue leads to the next: its text names the next beat's place
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: beats stay in the home sector when the galaxy has no far spine
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Story progress
Clues SHALL be found one after the other; the story SHALL follow the central mystery (it is off in the endless sandbox, Mystery: off) and have its own switch; a save SHALL keep only who found which beat and when, the text regenerating from the seed; saves made before the story (state version 10 or 11) SHALL load with a fresh story.

#### Scenario: clues unlock one after the other and the finale is not a clue
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the story follows the mystery: it is off in the sandbox and with its own switch
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the finale text follows the ending, with a fallback for an ending a mod adds
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: progress is what a save keeps: who found which beat, and it restores onto a fresh story
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a save keeps the story's progress and loading puts it back, with the same story regenerated
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a save from before the story (state version 10 or 11) loads with a fresh story of the same seed
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

### Requirement: Clues in the world
Each clue beat SHALL be a marker in its place: a wreck log or a mural in a derelict great hall, an archive record in a city's archive hall that reads only once its district's grid is restored. Only the next unfound clue SHALL be on offer, shared by the whole party; the beam SHALL read it in place (nothing rides in the hold), the finder is told, the others are told, and the clue is filed on every player's bookshelf.

#### Scenario: only the next clue is on offer, at its own site, and the one before unlocks it
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a clue lies a quarter of a great hall in from two walls, clear of the crates, in every kit
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a clue falls back to a smaller room when a site has no great hall, and to the first room when it has nothing else
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: an archive record sits in the city's archive hall and reads only once its district's grid is on
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a clue is found for the whole party: it is filed on every shelf and the others are told
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the story page on the shelf is the clue's text, in pages the book reader can turn
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: the log gets the clue in chunks of whole sentences
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: there are no clues in the sandbox, with the story switched off, or once they are all found
- **WHEN** `tests/lua/story_spec.lua` runs its scenario of this name
- **THEN** it passes

#### Scenario: a clue is read by the beam in a derelict, found, shelved, and survives a save and load
- **WHEN** `tests/game/story.lua (seeds 42 and 7, and with a restore every tick)` runs
- **THEN** it passes
