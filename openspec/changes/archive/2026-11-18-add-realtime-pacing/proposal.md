## Why

Scripted windowed runs (screenshot tours, screen recordings) advance one tick per
drawn frame with no frame cap. Under Xvfb with llvmpipe that is about 100 frames a
second, so recordings play about 1.7 times faster than the game really runs.

## What Changes

- ADDED `capture-tooling`: the `--realtime` flag (and `SAUCER_REALTIME=1`) paces a
  fixed-step scripted windowed run to the wall clock, 60 ticks a second.

## Impact

- Code: `engine/src/core/sx_engine.c` (`sx_pace_wait`, `sx_env_flag`, option parsing),
  `engine/src/platform/sx_sdl_main.c` (sleep at the end of `frame()`).
- No change to the simulation, saves or replays.
