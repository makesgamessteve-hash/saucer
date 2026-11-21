## 1. Sim

- [x] 1.1 `sim/hull.lua` retreat: tear away `ceil(#hot * retreat_lose)` items for good, cache the rest; `retreat_bill = { 40, 80, 140 }`, credits only at danger 1; retreat message in `sim/game.lua`
- [x] 1.2 `sim/sentry.lua`: `watcher.small_range` (40 m) for hulls below the band; light Watcher at the tutorial site (`light_room`, `watcher.light`); light range, lock time and bolt damage
- [x] 1.3 `sim/game.lua` new player: `upgrades = { beam_relay = 1 }`
- [x] 1.4 `sentry.bolt_hits_hull`: ellipsoid scaled by `watcher.hurt_scale` (0.8)
- [x] 1.5 Scanner finds (`game.scan_finds`), tool tips (`sentry.tip`), denied fallback (`game.TOOL_BUTTONS`, `DENY_WHY`)
- [x] 1.6 `sim/loot.lua` condition spread (`loot.condition`)
- [x] 1.7 State version 16; replays re-recorded

## 2. View

- [x] 2.1 `view/juice.lua`: trauma, shake, hitstop, flash; wired in `view/render.lua` and `view/hud.lua`
- [x] 2.2 `view/hud.lua`: text plates (`hud.plated`), hit frame (`hud.hit_flash`)
- [x] 2.3 `view/audio.lua`: one-shot pitch spread (`audio.pitch`)
- [x] 2.4 `meshes/interior.lua`: dome struts 0.05 x 0.04 m, the two flanking the view ahead removed

## 3. Tests

- [x] 3.1 `tests/lua/funfixes_spec.lua`
- [x] 3.2 Specs and game tests updated for the new defaults (`loop_spec`, `playtest_recs_spec`, `tests/game/sentries.lua`, `tests/game/trade.lua`, `tests/game/widerdark.lua`)
- [x] 3.3 Fun audit re-run (`docs/funaudit/2026-11-21-after.md`)
