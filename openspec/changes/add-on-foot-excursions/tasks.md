## 1. Derelict features

- [x] 1.1 `foot` sections of the kits; crawl mouth door class 0
- [x] 1.2 `sim/footgen.lua`: crawlspace, chamber and strongroom off a great hall, on the ruin's cell grid, own child rng
- [x] 1.3 Hand-lock, grid console, Delicate find and strongroom loot slot; shutter boxes in `sim/game.lua`

## 2. On foot

- [x] 2.1 Step out (Pocket size inside a derelict), fold into the hand, pocket, F holds the coin
- [x] 2.2 Walk, crouch (auto into low openings), crawl, jet-hop, mag-boot gravity
- [x] 2.3 Deploy with a 2.2 m clearance sphere (ahead, else around you), board, stow the hands
- [x] 2.4 Suit Charge drain (crawl and lock multipliers), warnings, Jammer cost, hop cost
- [x] 2.5 Four hand slots, carry size limit, Delicate finds, caches by hand
- [x] 2.6 Lifeline: trail, Seat on the newest valid point, cache where you fell
- [x] 2.7 Hand-locks open shutters; grid consoles hold sentries down until you leave
- [x] 2.8 Watchers see you on foot, bolts bite the suit, Snatchers tear items from your hands

## 3. Presentation

- [x] 3.1 Props (shutter, lock, console, Delicate finds, crawl mouth frame), hand, coin and morph (`view/excursion.lua`, `view/assets.lua`)
- [x] 3.2 HUD: suit bar and warnings, hand slots, coin, work progress, cache bearing, Lifeline white-out, help lines
- [x] 3.3 Chase camera on foot, other players on foot, derelict audio loop, XR wrist bars

## 4. Verification

- [x] 4.1 `tests/lua/excursion_spec.lua`
- [x] 4.2 Game test `tests/game/excursion.lua` (also restore-every-tick and seed 7)
- [x] 4.3 Ruin known answers and slice replay re-recorded; coverage at least 95% for C and Lua
- [x] 4.4 Screenshot tour `tools/shots/m7.lua`
