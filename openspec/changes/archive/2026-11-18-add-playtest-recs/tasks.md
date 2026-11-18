## 1. Spending and the lab (recommendations 1, 2)

- [x] 1.1 `economy/upgrades.lua` and `sim/upgrades.lua`: levels in `p.upgrades`, rows at the trade terminal and the chandler
- [x] 1.2 Effects: relay, pull factor, hold slots (every hold-size check), shield soak (`ship.cells`), lab slots
- [x] 1.3 `lab.push_front`: decodes ahead of Identify jobs; `lab.step` runs `slots(p)` jobs; HUD and lab rows show it

## 2. Danger (recommendations 3, 4, 7, 8)

- [x] 2.1 `galaxy.warning` / `fold_warn` panel, `p.braved`, `p.seat_dives`
- [x] 2.2 `sentry.seat_hint` on the first Watcher lock; `game.entry_text`
- [x] 2.3 `hull.bill` (`retreat_bill` in sentries.lua) and the retreat message
- [x] 2.4 The Warden ignores the grid (`warden.step(..., slow)`, `drowsy`)

## 3. Walking, stations, selling (recommendations 5, 6, 11)

- [x] 3.1 Helm beam relay in `tractor_step`, the HUD beam hint and `autopilot.pull`
- [x] 3.2 `visit.thief_roll` (`chance`, `quiet_visits`, `pity` in station/folk.lua)
- [x] 3.3 `trade.story_warning` / `confirm_sale` / `sell_text` at the terminal and stalls

## 4. Co-op (recommendation 9)

- [x] 4.1 `sim/twin.lua`: layout from the ruin, anchor and vault candidates, hold, take, drift
- [x] 4.2 Party requests in `sim/requests.lua` (posted on init, sector load and join)
- [x] 4.3 `coop.readiness` / `set_ready`, party panel rows, `hud.ready_line`

## 5. Controls and HUD (recommendation 10)

- [x] 5.1 `grapple` action (Y, D-pad up, key2 0, touch GRP), `SX_TOUCH_GRAPPLE`
- [x] 5.2 `hud.message_lines`, `hud.alerts`, `hud.hint_for`, `hud.wrap`; station overprint fixed

## 5½. Gameplay gaps (after milestone 10)

- [x] 5.3 Tractor Room target queue (`sim/beamqueue.lua`, `tractor_step`): a find not in lock joins a queue of four from the helm or the console and is pulled the moment it locks, so L and XL finds can be lined up for the console; HUD "BEAM QUEUE"
- [x] 5.4 Twin vaults and anchors stand on their own spots in their room (`twin.spot_of` picks the point of the room farthest from its loot slots, the Echo and home-find quarters, off the walls so a saucer can hover over it; at least `twin.SPOT_CLEAR` from every loot slot), so the find on the slot no longer comes up first
- [x] 5.5 Saucer modules and a trader's shelf (see `add-items-identification-tractor` 1.2 and `add-trading-mvp` 1.2)

## 6. Verification

- [x] 6.1 `tests/lua/playtest_recs_spec.lua`; game tests read the new warnings; C touch test
- [x] 6.2 Replays re-recorded; state version 10
- [x] 6.3 Ten playtest runs re-run and compared (docs/playtest/2026-11-17-after.md)
