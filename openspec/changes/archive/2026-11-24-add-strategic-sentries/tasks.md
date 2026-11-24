## 1. Sim

- [x] 1.1 `sim/stealth.lua`: signature, meter (`fill`, `step_meter`, `meter_on`); tuning in `data/base/sentries/sentries.lua` (`stealth`)
- [x] 1.2 Site alarm (`state.alarm`, `stealth.raise`, `stealth.step_alarm`): Snatchers wake, Lockdown trips (`sim/advsentry.lua`), faster fire
- [x] 1.3 Sweep patterns (`stealth.shape`, `pattern_of`, `sweep`); off-centre turrets; pillar cover and guarded finds (`stealth.decorate`)
- [x] 1.4 Guarded find premium (`sim/tractor.lua`, `game.scan_finds`); drops under its guard's eye (`sentry.guard_on`)
- [x] 1.5 Power cells (`tractor.cells`, `pull_time` by kind, `game.pick_up` kind `cell`, Override spike in `advsentry.spike_target`)
- [x] 1.6 Spotter (`sim/spotter.lua`, route from `warden.route`)
- [x] 1.7 State version 17; replays re-recorded

## 2. View

- [x] 2.1 `view/hud.lua`: suspicion arc (`hud.suspicion`), TAGGED and SITE ALARM alerts
- [x] 2.2 `view/render.lua`: floor light pools (`render.floor_cone`), the Spotter, scan marks for cones, cells and guarded finds

## 3. Tools and tests

- [x] 3.1 Stealth persona (`tools/funaudit/fun.lua`, `tools/playtest/bot.lua`), `tools/funaudit/sentry_table.py`
- [x] 3.2 `tests/lua/strategic_spec.lua`; `tests/game/strategic.lua` (meter rise/fall, guarded finds, sabotage, Spotter tag, alarm escalation and cooldown)
- [x] 3.3 Fun audit before/after (`docs/funaudit/2026-11-23-sentries.md`)
