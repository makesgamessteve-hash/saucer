## Why

Steve reported that the bedroom door "goes crazy" and "seems to be moving all the time" when he
walks near it (mobile web build). Reproduced in a game test: with a body standing still within
reach of the door, `home.doors_step` moved a fully open door `1.00 -> 0.95 -> 1.00` every tick (178
direction reversals in 3 s, and a "door" sound on every other tick), because the move was written
`if want > cur then up else down`, and the `else` also ran when the door was already at its goal.
The trigger also had no hysteresis, so a body swaying across the reach radius (a thumb on a touch
stick) flipped the goal, and the door's collision could switch on under a body standing in it.

## What Changes

- MODIFIED `saucer-interior`: Sliding doors: a door moves toward its goal and stops on it; it
  opens inside `reach`, only starts to close once every body is beyond `reach + door_close_margin`
  (0.5 m), stays open for at least `door_min_open` (0.8 s) after a trigger, and is never solid
  under a body that overlaps it. The leaf is drawn with a smoothstep ease (the sim stays linear).
- State version 12 (the player gains `door_goal` and `door_hold`); replays re-recorded.
