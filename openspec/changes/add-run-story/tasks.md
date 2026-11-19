## 1. The generator (slice 1)
- [x] 1.1 `data/base/story/skeletons.lua`, `twists.lua`, `vocab.lua`: five skeletons of 4 to 6 beats, six twists, trait words
- [x] 1.2 `sim/story.lua` `generate`: skeleton, cast, Echo, betrayal, twist, beats bound to sites, text with leads
- [x] 1.3 `state.story` in `game.init`, `story.progress` / `story.restore` in saves, state version 13, replays re-recorded
- [x] 1.4 `tests/lua/story_spec.lua` (determinism across seeds, bindings, leads, twists, progress, saves, v10 migration)
## 2. Clues in the world (slice 2)
- [x] 2.1 `story.candidates`: wreck logs and murals in derelict halls, archive records in city archives (power gated)
- [x] 2.2 `game.pick_up` kind `story`: found, shared by the party, filed on the shelf, lead message
- [x] 2.3 Render the clue markers by carrier; tests and the game test `tests/game/story.lua`
## 3. Codex, hints and ending (slice 3)
- [x] 3.1 The Story page at the holotable (panel `story`), stitched from clues, Echoes and places
- [x] 3.2 HUD hint in hints mode; Mystery: off hides the story
- [x] 3.3 The finale at the Heart (ending and twist), final book, the story in the ending screen
- [x] 3.4 Screenshots, ROADMAP, README
