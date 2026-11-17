## ADDED Requirements

### Requirement: Cooking for buffs
The stove SHALL open a galley panel listing recipes and the pantry. Cooking a recipe SHALL take its ingredients, hold the player at the stove for a few seconds and then give the recipe's timed buffs. Buffs SHALL scale Charge regen, Scanner and Jammer cooldowns, Scanner reveal time or hull regen while they last.

#### Scenario: Spiced noodles
- **WHEN** a player with noodles and Velari spice cooks Ember-spiced noodles
- **THEN** after the cooking time they are well fed and keen

### Requirement: Bookshelf
The bookshelf SHALL hold the starter manual plus books and logs found in derelicts, decoded Echo transcripts and holodeck memories. Reading SHALL show one page at a time. The first read of a clue SHALL mark a lead on the site it names.

#### Scenario: Read a found log
- **WHEN** a player reads the Velari captain's log to the end
- **THEN** a lead is marked and the book closes after the last page

### Requirement: TV hints
The TV SHALL receive channels from the nearest station of each channel's kind within range. Watching SHALL show the channel, its current show and a hint about the game state. Use SHALL flip to the next channel and finally switch off; moving SHALL get the player up.

#### Scenario: Watch the TV
- **WHEN** a player near the trader switches on the TV
- **THEN** a channel is received and a hint is shown

### Requirement: Home state is saved and deterministic
Shelf, pantry, holodeck library and modules, best times, buffs, trails and leads SHALL be saved with the player. Seated modes (holodeck run, TV, reading, cooking) SHALL NOT be saved. Program scenes SHALL derive only from the world seed, the program, its argument and the installed modules.

#### Scenario: Save and load
- **WHEN** a player with a shelved log, alien ingredients, an unlocked program and an active buff saves and loads while watching TV
- **THEN** all of these come back and the player is not watching TV
