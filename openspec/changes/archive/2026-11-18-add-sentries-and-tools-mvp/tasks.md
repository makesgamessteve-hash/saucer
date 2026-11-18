## 1. Requirements

- [x] 1.1 Sentry state machine (milestone 3): `sim/sentry.lua`; state lights in `view/render.lua`; leash per duct branch; game test `sentries.lua` "at least 0.75 s in Alert first"
- [x] 1.2 Watcher (milestone 3): cone and size band, stun bolts; `sentries.lua` "stun bolts hit the shields", "Watcher Dormant within 2 s" (the Seat is below the band); Suit Charge on foot waits for excursions
- [x] 1.3 Snatcher (milestone 3): Seat-only latch, 3 s siphon, nest recovery; `sentries.lua` "it stole on the next try", "tractored the item back from the nest"; on-foot latch waits for excursions
- [x] 1.4 Non-lethal tools (milestone 3): Scanner (V / pad Y / touch SCAN) and Jammer (T / right stick click / touch JAM), costs in `sentries/sentries.lua`; `sentries.lua` "the scanner reads the site", "jammed: the Snatcher reboots"
- [x] 1.5 Grid consoles (on-foot hand-lock, `sim/excursion.lua` `shut_grid`/`grid_down`/`left_site`, milestone 7 `add-on-foot-excursions`): every derelict has one in its crawlspace; holding Use at it puts the site's sentries down until you leave. Tests: `tests/lua/excursion_spec.lua` "the grid console holds a site's sentries down until you leave", "turns the hand-lock (the shutter opens) and shuts the grid at its console", `tests/lua/gameplay_gaps_spec.lua` "every derelict with sentries has a grid console that stands them down" and `tests/game/excursion.lua`
- [x] 1.6 The dome is out of reach (milestone 3): sentries act on hulls only (bolts hit `ship`, Snatchers take from the hold); no sentry reads or moves the body

## 2. Verification

- [x] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten. Verified at suite level at archive time (2026-11-18): the scenarios are exercised by the C unit tests, game tests and Lua specs named in the requirement tasks above and in the capability spec; the whole suite (ctest 41/41, 385 Lua specs, coverage gates C 98.3% and Lua 98.29%) is green on all four CI platforms in main run @RUN@. Scenarios were not individually re-mapped in housekeeping.
- [x] 2.2 Archive this change (`openspec archive`) after CI is green (archived as `2026-11-18-add-sentries-and-tools-mvp`)
