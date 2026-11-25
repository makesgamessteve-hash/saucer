## ADDED Requirements

### Requirement: Relic pocket rooms and lore niches
On foot in a relic, the excursion SHALL know every crawlspace and pocket room, and the HUD SHALL name them CRAWLSPACE and POCKET. A pocket room SHALL hold one thing: the hand-lock, a Delicate find, a sentry-grid console or a lore niche. Use at a lore niche SHALL show its glyph text (USE: READ THE GLYPHS), taken from the civ's lore, with a fallback line for the Vyrr slice. A turned lock SHALL say whether it opened a sealed chamber or the reliquary.

#### Scenario: Lore niche
- **WHEN** `tests/lua/relicfoot_spec.lua` runs "reads a lore niche's glyphs by hand and names the pocket room"
- **THEN** it passes

#### Scenario: Lock messages
- **WHEN** `tests/lua/relicfoot_spec.lua` runs "says which door a Seat-lock opened, and the hand-lock opens a relic chamber"
- **THEN** it passes
