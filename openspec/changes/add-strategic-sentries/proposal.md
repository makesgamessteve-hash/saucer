## Why

Steve asked for the play between sentries and the saucer to be more strategic. The 2026-11-21 fun
audit and its follow-up showed a Watcher is a binary switch: a hull is seen or it is not, a lock
costs a few shield points, nothing remembers it, and a BeamOnly bot that ignores every tool banks
about 2x what careful play does. Steve picked all seven proposed changes: give detection a gradient
the player can read and manage, make being seen escalate, put the best loot where the sentries look,
make the sweeps learnable with cover to use, let the player take a Watcher out by stealth, add a
sentry that informs rather than shoots, and measure all of it with a Stealth bot persona.

## What Changes

- MODIFIED `sentries-and-tools` Watcher: a suspicion meter (0-1) fills while a Watcher sees the
  player, scaled by a signature (hull size, speed, a working beam, Loud modules) and closeness; Alert
  at 0.5, Locked only at 1 after the Alert time; it drains out of sight; after a lost lock it keeps a
  memory (0.45). With no `stealth` tuning the meter is all or nothing, as before.
- ADDED `sentries-and-tools`: the site alarm (each lock or Spotter tag raises it, max 3, the tutorial
  derelict 1; at 2 the Snatchers wake and a Lockdown trips; locked Watchers fire sooner per level; it
  cools a level per 30 s away or 90 s inside with no sentry hunting); readable sweep patterns (smooth,
  stepped, holding) and periods per turret, a floor light pool, pillar cover and off-centre turrets;
  a guarded find on the floor in each hall Watcher's cone, worth 1.6x, that drops back out of the beam
  while its guard is at Alert or Lock on you; a rear power cell per hall Watcher (a 3 s pull with the
  beam or the Override spike: the Watcher goes dark for good and the cell sells; seen while pulling,
  it locks at once and raises the alarm); the Spotter drone (patrols, never fires, tags: every Watcher
  meter jumps to 0.9 and the alarm rises; a Decoy takes it, the Jammer stuns it); the HUD suspicion arc
  and alarm line, and the Scanner draws cones, cells, guarded marks and the alarm.
- ADDED a Stealth persona to `tools/funaudit` and `tools/playtest` (scan on entry, Decoy on Alert,
  Jam on Lock, lie low while suspected, pull Watcher cells).
- State version 17; the seed-42 replays are re-recorded.
