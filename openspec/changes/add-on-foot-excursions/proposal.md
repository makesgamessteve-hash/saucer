## Why

Roadmap milestone 7: step out of the saucer into a derelict for the places
no saucer fits. Crawlspaces, hand-locks and grid consoles give a derelict a
second layer that only a person on foot can open, and the Lifeline makes
leaving the saucer a risk you can always come back from (concept §3.5, §4).

## What Changes

- ADDED `on-foot`: Step out in a derelict
- ADDED `on-foot`: Deploy and board
- ADDED `on-foot`: Movement on foot
- ADDED `on-foot`: Suit Charge
- ADDED `on-foot`: Four hand slots
- ADDED `on-foot`: Lifeline
- ADDED `on-foot`: Crawlspaces, chambers and strongrooms
- ADDED `on-foot`: Hand-locks open doors for the saucer
- ADDED `on-foot`: Grid consoles
- ADDED `on-foot`: Sentries against a person on foot
- ADDED `on-foot`: Excursions save and replay
- ADDED `on-foot`: Excursion presentation on every device

New data: `foot/excursion.lua` (suit, hands, body, deploy, work timings), the
`foot` sections of `kits/{starship,station,city}.lua` (crawl mouth door,
chamber and strongroom sizes), `sentries/sentries.lua` (`watcher.foot_range`,
`snatcher.foot_sense`, `jammer.suit`).
New scripts: `sim/footgen.lua`, `sim/excursion.lua`, `view/excursion.lua`.
Save state version 8 (`p.excursion`, `p.suit`, `p.hands`, `state.locks`,
`state.grids`).

## Impact

- Capability `on-foot` (`openspec/specs/on-foot/spec.md` once archived)
- Supersedes `add-on-foot-pocket-mode` (its two requirements are met here in
  more detail; that change is marked superseded)
- Reuses the Pocket configuration and on-foot movement of
  `add-pocket-station-visits`, and the presentation, audio and XR systems of
  `add-presentation-packaging`
- Known answers: `tests/lua/ruin_spec.lua` wall counts (the foot rooms add walls;
  room layouts and `layout_hash` are unchanged) and
  `tests/replays/slice_seed42.srep` re-recorded for state version 8
- No lethal weapons: the only things you do to a sentry are jam it or shut
  its grid down
