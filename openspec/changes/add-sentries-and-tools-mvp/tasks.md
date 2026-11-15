## 1. Requirements

- [x] 1.1 Sentry state machine (milestone 3): `sim/sentry.lua`; state lights in `view/render.lua`; leash per duct branch; game test `sentries.lua` "at least 0.75 s in Alert first"
- [x] 1.2 Watcher (milestone 3): cone and size band, stun bolts; `sentries.lua` "stun bolts hit the shields", "Watcher Dormant within 2 s" (the Seat is below the band); Suit Charge on foot waits for excursions
- [x] 1.3 Snatcher (milestone 3): Seat-only latch, 3 s siphon, nest recovery; `sentries.lua` "it stole on the next try", "tractored the item back from the nest"; on-foot latch waits for excursions
- [x] 1.4 Non-lethal tools (milestone 3): Scanner (V / pad Y / touch SCAN) and Jammer (T / right stick click / touch JAM), costs in `sentries/sentries.lua`; `sentries.lua` "the scanner reads the site", "jammed: the Snatcher reboots"
- [ ] 1.5 Grid consoles: deferred (they are an on-foot hand-lock; on-foot excursions are not in the game yet)
- [x] 1.6 The dome is out of reach (milestone 3): sentries act on hulls only (bolts hit `ship`, Snatchers take from the hold); no sentry reads or moves the body

## 2. Verification

- [ ] 2.1 Every scenario above is covered by a named test that passes in CI on linux-gcc, linux-clang, windows-msvc and emscripten
- [ ] 2.2 Archive this change (`openspec archive`) after CI is green
