# persistence Specification

## Purpose
The game saves as the universe seed plus diffs and rebuilds the universe on load.

## Requirements

### Requirement: Save as seed plus diffs
A save SHALL record the format version, the game version, the seed, the mod list, world diffs (tick, mystery progress, and later traders, nests, caches and vault) and one record per player (body, ship, hold, banked loot and progress), written atomically to `saves/slot1.sav` in the user directory. Transient state such as messages, effects and open panels SHALL NOT be saved.

#### Scenario: Sleep then load
- **WHEN** the player sleeps in the bed, walks away, and loads the save at the bed
- **THEN** the tick, the player's position and their records are exactly as they were when they slept

### Requirement: Loading rebuilds the universe
Loading SHALL rebuild the universe from the saved seed for the current number of local players and lay the saved diffs over it. Only player 1 SHALL be able to load. A missing or unreadable save SHALL be reported, and a save made with a different mod set SHALL need a second confirmation.

#### Scenario: Different mods
- **WHEN** a save made with another mod set is loaded
- **THEN** the player is warned once and the save loads when they pick Load again
