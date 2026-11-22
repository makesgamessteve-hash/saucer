## Why

The 2026-11-21 fun audit (`docs/funaudit/2026-11-21.md`, harness `tools/funaudit/`) scored Saucer
S_fun 65.3. Its six findings: risk costs nothing (a BeamOnly bot that ignores every tool and takes
~100 hits banks 1.03x what careful play does), the first threat comes late and the Seat is a free
pass past every Watcher, the helm beam relay that makes the helm worth sitting at is bought late,
the bolt collider is a box around a disc (corner hits), hits carry little feedback and HUD text sits
straight on a bright scene (contrast 1.9:1), and the tools other than Tractor and fold are never
needed (tool entropy 0.21), presses that do nothing are silent, and loot values barely vary.
Steve asked for all six fixes, on by default, keeping the game non-lethal.

## What Changes

- MODIFIED `hazards-and-failure`: a Fold Retreat tears half the hot cargo (rounded up, newest first)
  away for good and caches the rest; the tow bill is 40 / 80 / 140 c by danger (2x-4x for tows within 10 minutes of the last), and at danger 1 it
  comes out of credits only (never the Charge).
- MODIFIED `sentries-and-tools`: a Watcher sees a hull below its band (the Seat) within 25 m; the
  tutorial derelict (site 1) keeps one light Watcher (55 m / 15 m range, 1.5 s lock, 4-damage
  bolts) in its biggest non-entrance room; bolts hit a saucer-shaped ellipsoid (0.8 of the hull)
  instead of a cylinder; the Seat hint says the Seat is seen up close.
- ADDED `sentries-and-tools`: tool jobs and feedback: the Scanner also reports the finds left in a
  site and the best one's room; one-time tips teach the Decoy on a Watcher lock and the Jammer on a
  Snatcher lock; a tool press that changes nothing plays "denied" and says why (once per 10 s).
- ADDED `saucer-upgrades`: the helm beam relay comes fitted on a new pilot.
- ADDED `items-and-identification`: a condition roll spreads loot values 0.6x-1.8x.
- ADDED `hud-readability`: dark plates behind HUD text; a red hit frame. ADDED `audio-presentation`:
  one-shot pitch +-8 %. ADDED `saucer-interior`: slimmer dome struts, none flanking the view ahead.
  Camera trauma and a 50 ms hitstop on a hit (view only, none in XR).
- State version 16; the seed-42 replays are re-recorded.
